import AppKit
import Carbon.HIToolbox
import Combine
import CoreGraphics
import SwiftUI

struct ModifierMask: Codable, Hashable {
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool

    static let recommended = ModifierMask(command: false, option: true, control: true, shift: false)
    static let relevantCGFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]

    var isEmpty: Bool {
        !command && !option && !control && !shift
    }

    var displayName: String {
        var parts: [String] = []
        if command { parts.append("Command") }
        if option { parts.append("Option") }
        if control { parts.append("Control") }
        if shift { parts.append("Shift") }
        return parts.joined(separator: " + ")
    }

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if command { flags.insert(.maskCommand) }
        if option { flags.insert(.maskAlternate) }
        if control { flags.insert(.maskControl) }
        if shift { flags.insert(.maskShift) }
        return flags
    }

    func matches(_ flags: CGEventFlags) -> Bool {
        flags.intersection(Self.relevantCGFlags) == cgEventFlags
    }
}

struct DisplayShortcut: Identifiable, Hashable {
    let number: Int
    let displayID: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let visibleFrame: CGRect
    let isPrimary: Bool
    let scaleFactor: CGFloat
    let isBuiltin: Bool

    var id: CGDirectDisplayID { displayID }

    var frameDescription: String {
        return ""
    }
}

enum InputMonitoringStatus {
    case unauthorized
    case awaitingApproval
    case authorized
}

final class GlobalHotKeyMonitor {
    typealias ShortcutProvider = () -> [CGDirectDisplayID: ShortcutKey]
    typealias ToggleShortcutProvider = () -> ShortcutKey?
    typealias MatchHandler = @MainActor (CGDirectDisplayID) -> Void
    typealias ToggleMatchHandler = @MainActor () -> Void
    typealias StatusHandler = @MainActor (String) -> Void

    private let shortcutProvider: ShortcutProvider
    private let toggleShortcutProvider: ToggleShortcutProvider
    private let onMatch: MatchHandler
    private let onToggleMatch: ToggleMatchHandler
    private let onStatusChange: StatusHandler

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        shortcutProvider: @escaping ShortcutProvider,
        toggleShortcutProvider: @escaping ToggleShortcutProvider,
        onMatch: @escaping MatchHandler,
        onToggleMatch: @escaping ToggleMatchHandler,
        onStatusChange: @escaping StatusHandler
    ) {
        self.shortcutProvider = shortcutProvider
        self.toggleShortcutProvider = toggleShortcutProvider
        self.onMatch = onMatch
        self.onToggleMatch = onToggleMatch
        self.onStatusChange = onStatusChange
    }

    deinit {
        stop()
    }

    var isRunning: Bool {
        eventTap != nil
    }

    static func hasPermission() -> Bool {
        CGPreflightListenEventAccess()
    }

    @discardableResult
    static func requestPermission() -> Bool {
        CGRequestListenEventAccess()
    }

    func startIfPossible() {
        guard !isRunning else { return }

        guard Self.hasPermission() else {
            Task { @MainActor in
                onStatusChange("尚未获得输入监控权限，暂时无法在后台监听全局数字快捷键。")
            }
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let monitor = Unmanaged<GlobalHotKeyMonitor>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                monitor.handle(eventType: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            Task { @MainActor in
                onStatusChange("创建全局事件监听失败，请确认系统权限是否已生效。")
            }
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            CFMachPortInvalidate(tap)
            Task { @MainActor in
                onStatusChange("创建事件监听 RunLoop 失败。")
            }
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source

        Task { @MainActor in
            onStatusChange("全局快捷键监听已启动，可在后台响应跨屏跳转。")
        }
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func handle(eventType: CGEventType, event: CGEvent) {
        guard eventType == .keyDown else { return }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        
        if let toggleShortcut = toggleShortcutProvider(), toggleShortcut.matches(event.flags, keyCode: keyCode) {
            Task { @MainActor in
                onToggleMatch()
            }
            return
        }
        
        let shortcuts = shortcutProvider()

        for (displayID, shortcut) in shortcuts {
            if shortcut.matches(event.flags, keyCode: keyCode) {
                Task { @MainActor in
                    onMatch(displayID)
                }
                return
            }
        }
    }
}

enum ScreenJumpService {
    @discardableResult
    static func jumpCursor(to target: DisplayShortcut, among displays: [DisplayShortcut]) -> CGError {
        let currentLocation = CGEvent(source: nil)?.location ?? .zero
        let source = displays.first { $0.frame.contains(currentLocation) }
        let targetPoint = destinationPoint(for: currentLocation, from: source, to: target)
        return CGWarpMouseCursorPosition(targetPoint)
    }

    private static func destinationPoint(
        for currentLocation: CGPoint,
        from source: DisplayShortcut?,
        to target: DisplayShortcut
    ) -> CGPoint {
        let targetFrame = target.visibleFrame.insetBy(dx: 24, dy: 24)

        guard let source else {
            return CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        }

        let sourceFrame = source.visibleFrame.insetBy(dx: 24, dy: 24)
        let xRatio = normalizedRatio(value: currentLocation.x, min: sourceFrame.minX, max: sourceFrame.maxX)
        let yRatio = normalizedRatio(value: currentLocation.y, min: sourceFrame.minY, max: sourceFrame.maxY)

        return CGPoint(
            x: targetFrame.minX + xRatio * targetFrame.width,
            y: targetFrame.minY + yRatio * targetFrame.height
        )
    }

    private static func normalizedRatio(value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        guard max > min else { return 0.5 }
        return Swift.min(1, Swift.max(0, (value - min) / (max - min)))
    }
}

@MainActor
final class ScreenOverlayManager {
    private var windows: [CGDirectDisplayID: NSPanel] = [:]
    private var cursorIndicatorPanel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func showLabels(for displays: [DisplayShortcut], shortcuts: [CGDirectDisplayID: ShortcutKey]) {
        hide()

        for display in displays {
            let panel = makePanel(for: display, shortcut: shortcuts[display.displayID])
            windows[display.displayID] = panel
            panel.orderFrontRegardless()
        }

        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                self.hide()
            }
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        windows.values.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    func showCursorIndicator(at point: CGPoint, in displayFrame: CGRect) {
        let indicatorSize: CGFloat = 160
        let indicatorFrame = CGRect(
            x: point.x - indicatorSize / 2,
            y: point.y - indicatorSize / 2,
            width: indicatorSize,
            height: indicatorSize
        )

        let panel = NSPanel(
            contentRect: indicatorFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.cursorWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.contentView = NSHostingView(rootView: CursorIndicatorView())

        DispatchQueue.main.async { [weak self] in
            panel.orderFrontRegardless()
            self?.cursorIndicatorPanel = panel
        }

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run { [weak self] in
                panel.orderOut(nil)
                if self?.cursorIndicatorPanel === panel {
                    self?.cursorIndicatorPanel = nil
                }
            }
        }
    }

    private func makePanel(for display: DisplayShortcut, shortcut: ShortcutKey?) -> NSPanel {
        let panel = NSPanel(
            contentRect: display.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.contentView = NSHostingView(rootView: ScreenOverlayView(display: display, shortcut: shortcut))
        panel.setFrame(display.frame, display: true)
        return panel
    }
}

private struct ScreenOverlayView: View {
    let display: DisplayShortcut
    let shortcut: ShortcutKey?

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)

            VStack(spacing: 24) {
                Text(shortcut?.displayName ?? "未设置快捷键")
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)

                VStack(spacing: 8) {
                    Text(display.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())

                    if display.isPrimary {
                        Text("主屏幕")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.2), in: Capsule())
                    }
                }
            }
        }
    }
}

private struct CursorIndicatorView: View {
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.6), lineWidth: 3)
                .frame(width: 120, height: 120)
                .scaleEffect(isVisible ? 1.0 : 1.8)
                .opacity(isVisible ? 0 : 1)

            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 100, height: 100)
                .scaleEffect(isVisible ? 1.0 : 1.5)
                .opacity(isVisible ? 0 : 1)

            Circle()
                .fill(.white.opacity(0.25))
                .frame(width: 24, height: 24)
                .scaleEffect(isVisible ? 1.0 : 1.3)
                .opacity(isVisible ? 0 : 1)
        }
        .animation(.easeOut(duration: 1.0), value: isVisible)
        .onAppear {
            isVisible = true
        }
    }
}

@MainActor
final class MouseDanceStore: ObservableObject {
    @Published private(set) var displays: [DisplayShortcut] = []
    @Published private(set) var totalScreenCount = 0
    @Published private(set) var inputMonitoringGranted = false
    @Published private(set) var inputMonitoringStatus: InputMonitoringStatus = .unauthorized
    @Published private(set) var statusMessage = "等待初始化..."
    @Published private(set) var hasMarkedScreens = false
    @Published private(set) var lastMarkedAt: Date?

    @Published var screenShortcuts: [CGDirectDisplayID: ShortcutKey] = [:] {
        didSet {
            saveScreenShortcuts()
        }
    }

    @Published var toggleShortcut: ShortcutKey? {
        didSet {
            saveToggleShortcut()
        }
    }

    private let overlayManager = ScreenOverlayManager()
    private lazy var hotKeyMonitor = GlobalHotKeyMonitor(
        shortcutProvider: { [weak self] in
            self?.screenShortcuts ?? [:]
        },
        toggleShortcutProvider: { [weak self] in
            self?.toggleShortcut
        },
        onMatch: { [weak self] displayID in
            self?.jumpToScreen(displayID: displayID)
        },
        onToggleMatch: { [weak self] in
            self?.toggleScreen()
        },
        onStatusChange: { [weak self] message in
            self?.statusMessage = message
        }
    )

    private var screenObserver: NSObjectProtocol?
    private var windowCloseObserver: NSObjectProtocol?
    private var hasStarted = false
    private let previewMode: Bool
    private var shouldAutoRestartAfterPermissionGrant = false
    private var lastActiveDisplayID: CGDirectDisplayID?

    private static let shortcutsStorageKey = "mouseDance.screenShortcuts"
    private static let toggleShortcutStorageKey = "mouseDance.toggleShortcut"

    init(previewMode: Bool = false) {
        self.previewMode = previewMode
        self.screenShortcuts = Self.loadScreenShortcuts()
        self.toggleShortcut = Self.loadToggleShortcut()

        if previewMode {
            displays = Self.previewDisplays
            totalScreenCount = displays.count
            inputMonitoringGranted = true
            inputMonitoringStatus = .authorized
            statusMessage = "预览模式"
            hasMarkedScreens = true
            lastMarkedAt = Date()
        }
    }

    func binding(for displayID: CGDirectDisplayID) -> Binding<ShortcutKey?> {
        Binding(
            get: { self.screenShortcuts[displayID] },
            set: { self.screenShortcuts[displayID] = $0 }
        )
    }

    func start() {
        guard !previewMode else { return }
        guard !hasStarted else { return }
        hasStarted = true

        refreshScreens(updateStatus: false)
        refreshPermissionState(startMonitor: true)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.refreshScreens(updateStatus: false)
                self.statusMessage = "检测到显示器变化，可点击「重新标记屏幕」同步最新编号。"
            }
        }

        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            let normalWindows = NSApp.windows.filter { window in
                window.styleMask.contains(.titled) && !(window is NSPanel)
            }
            if normalWindows.isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    func relabelScreens() {
        refreshScreens(updateStatus: false)
        guard !displays.isEmpty else {
            statusMessage = "当前没有可标记的活动显示器。"
            return
        }

        overlayManager.showLabels(for: displays, shortcuts: screenShortcuts)
        hasMarkedScreens = true
        lastMarkedAt = Date()

        statusMessage = "屏幕标记完成，快捷键已按最新配置立即生效。"
    }

    func requestInputMonitoringAccess() {
        if GlobalHotKeyMonitor.hasPermission() {
            shouldAutoRestartAfterPermissionGrant = false
            refreshPermissionState(startMonitor: true)
            statusMessage = "输入监控权限已可用。"
            return
        }

        shouldAutoRestartAfterPermissionGrant = true
        inputMonitoringStatus = .awaitingApproval
        let _ = GlobalHotKeyMonitor.requestPermission()
        let didOpenSettings = openInputMonitoringSettings()
        statusMessage = didOpenSettings
            ? "系统已打开“隐私与安全性 > 输入监控”，请勾选 MouseDance，授权成功后应用会自动重启。"
            : "系统已发起输入监控授权请求，请手动前往“隐私与安全性 > 输入监控”允许本应用。"

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            self.refreshPermissionState(startMonitor: true)
        }
    }

    func refreshInputMonitoringState() {
        refreshPermissionState(startMonitor: true)
    }

    func recheckInputMonitoringAccess() {
        refreshPermissionState(startMonitor: true)
        if inputMonitoringGranted {
            statusMessage = "输入监控权限已可用。"
        } else if shouldAutoRestartAfterPermissionGrant {
            statusMessage = "仍在等待输入监控授权，请在“隐私与安全性 > 输入监控”中勾选 MouseDance。"
        } else {
            statusMessage = "尚未获得输入监控权限，后台全局快捷键暂不可用。"
        }
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func restartApplication() {
        relaunchApplication()
    }

    func terminateApplication() {
        NSApp.terminate(nil)
    }

    func jumpToDisplay(_ display: DisplayShortcut) {
        let currentLocation = CGEvent(source: nil)?.location ?? .zero
        let currentDisplayID = displays.first(where: { $0.frame.contains(currentLocation) })?.displayID

        if let current = currentDisplayID, current != display.displayID {
            lastActiveDisplayID = current
        }

        let result = ScreenJumpService.jumpCursor(to: display, among: displays)
        if result == .success {
            let targetPoint = CGEvent(source: nil)?.location ?? .zero
            overlayManager.showCursorIndicator(at: targetPoint, in: display.frame)
            statusMessage = "鼠标已跳转到屏幕：\(display.name)。"
        } else {
            statusMessage = "鼠标跳转失败，系统返回：\(result.rawValue)。"
        }
    }

    @discardableResult
    private func openInputMonitoringSettings() -> Bool {
        if let privacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"),
           NSWorkspace.shared.open(privacyURL) {
            return true
        }

        if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension") {
            return NSWorkspace.shared.open(settingsURL)
        }

        return false
    }

    private func relaunchApplication() {
        let bundleURL = Bundle.main.bundleURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [bundleURL.path]

        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            statusMessage = "检测到权限已生效，但自动重启失败，请手动重启应用。"
            shouldAutoRestartAfterPermissionGrant = false
            inputMonitoringStatus = resolvedInputMonitoringStatus()
        }
    }

    private func jumpToScreen(displayID: CGDirectDisplayID) {
        guard let target = displays.first(where: { $0.displayID == displayID }) else {
            return
        }
        jumpToDisplay(target)
    }

    private func toggleScreen() {
        let currentLocation = CGEvent(source: nil)?.location ?? .zero
        guard let source = displays.first(where: { $0.frame.contains(currentLocation) }) else { return }
        
        let currentDisplayID = source.displayID
        let targetDisplayID: CGDirectDisplayID
        
        if let lastID = lastActiveDisplayID, lastID != currentDisplayID, displays.contains(where: { $0.displayID == lastID }) {
            targetDisplayID = lastID
        } else {
            guard displays.count > 1 else { return }
            if let index = displays.firstIndex(where: { $0.displayID == currentDisplayID }) {
                let nextIndex = (index + 1) % displays.count
                targetDisplayID = displays[nextIndex].displayID
            } else {
                targetDisplayID = displays[0].displayID
            }
        }
        
        jumpToScreen(displayID: targetDisplayID)
    }

    private func refreshScreens(updateStatus: Bool) {
        let mainDisplayID = NSScreen.main?.mouseDanceDisplayID
        let allScreens = NSScreen.screens.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX {
                return lhs.frame.minX < rhs.frame.minX
            }
            if lhs.frame.minY != rhs.frame.minY {
                return lhs.frame.minY > rhs.frame.minY
            }
            return lhs.localizedName < rhs.localizedName
        }

        totalScreenCount = allScreens.count

        var newDisplays: [DisplayShortcut] = []
        for (index, screen) in allScreens.enumerated() {
            guard let displayID = screen.mouseDanceDisplayID else { continue }
            newDisplays.append(DisplayShortcut(
                number: index + 1,
                displayID: displayID,
                name: screen.localizedName,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                isPrimary: displayID == mainDisplayID,
                scaleFactor: screen.backingScaleFactor,
                isBuiltin: CGDisplayIsBuiltin(displayID) != 0
            ))

            // Assign default shortcut if none exists
            if screenShortcuts[displayID] == nil {
                screenShortcuts[displayID] = Self.defaultShortcut(for: index)
            }
        }
        
        displays = newDisplays

        if updateStatus {
            statusMessage = displays.isEmpty
                ? "当前没有活动显示器。"
                : "已刷新显示器列表，共识别到 \(totalScreenCount) 块屏幕。"
        }
    }

    private static func defaultShortcut(for index: Int) -> ShortcutKey {
        let digits: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]
        let keyString = "\(index + 1)"
        let keyCode = index < digits.count ? digits[index] : digits[0]
        return ShortcutKey(modifiers: .recommended, keyCode: keyCode, keyString: keyString)
    }

    private func refreshPermissionState(startMonitor: Bool) {
        let wasGranted = inputMonitoringGranted
        inputMonitoringGranted = GlobalHotKeyMonitor.hasPermission()
        inputMonitoringStatus = resolvedInputMonitoringStatus()
        if inputMonitoringGranted {
            if !wasGranted && shouldAutoRestartAfterPermissionGrant {
                shouldAutoRestartAfterPermissionGrant = false
                relaunchApplication()
                return
            }
            if startMonitor {
                hotKeyMonitor.startIfPossible()
            }
        } else {
            hotKeyMonitor.stop()
        }
    }

    private func resolvedInputMonitoringStatus() -> InputMonitoringStatus {
        if inputMonitoringGranted {
            return .authorized
        }
        return shouldAutoRestartAfterPermissionGrant ? .awaitingApproval : .unauthorized
    }

    private func saveScreenShortcuts() {
        guard let data = try? JSONEncoder().encode(screenShortcuts) else { return }
        UserDefaults.standard.set(data, forKey: Self.shortcutsStorageKey)
    }

    private func saveToggleShortcut() {
        if let shortcut = toggleShortcut, let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: Self.toggleShortcutStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.toggleShortcutStorageKey)
        }
    }

    private static func loadScreenShortcuts() -> [CGDirectDisplayID: ShortcutKey] {
        guard let data = UserDefaults.standard.data(forKey: shortcutsStorageKey),
              let dict = try? JSONDecoder().decode([CGDirectDisplayID: ShortcutKey].self, from: data) else {
            return [:]
        }
        return dict
    }

    private static func loadToggleShortcut() -> ShortcutKey? {
        guard let data = UserDefaults.standard.data(forKey: toggleShortcutStorageKey),
              let shortcut = try? JSONDecoder().decode(ShortcutKey.self, from: data) else {
            return nil
        }
        return shortcut
    }

    private static let previewDisplays: [DisplayShortcut] = [
        DisplayShortcut(
            number: 1,
            displayID: 1,
            name: "Studio Display",
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1400),
            isPrimary: true,
            scaleFactor: 2,
            isBuiltin: true
        ),
        DisplayShortcut(
            number: 2,
            displayID: 2,
            name: "LG UltraFine",
            frame: CGRect(x: 2560, y: 0, width: 3840, height: 2160),
            visibleFrame: CGRect(x: 2560, y: 0, width: 3840, height: 2120),
            isPrimary: false,
            scaleFactor: 2,
            isBuiltin: false
        ),
    ]
}

extension NSScreen {
    var mouseDanceDisplayID: CGDirectDisplayID? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }
}
