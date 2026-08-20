import AppKit
import Carbon.HIToolbox
import Combine
import CoreGraphics
import ServiceManagement
import SwiftUI

struct ModifierMask: Codable, Hashable {
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool

    static let recommended = ModifierMask(command: true, option: true, control: false, shift: false)
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

    var pixelSize: CGSize {
        let fallbackWidth = frame.width * max(scaleFactor, 1)
        let fallbackHeight = frame.height * max(scaleFactor, 1)
        let pixelWidth = CGFloat(CGDisplayPixelsWide(displayID))
        let pixelHeight = CGFloat(CGDisplayPixelsHigh(displayID))

        return CGSize(
            width: pixelWidth > 0 ? pixelWidth : fallbackWidth,
            height: pixelHeight > 0 ? pixelHeight : fallbackHeight
        )
    }

    var pixelsPerPointX: CGFloat {
        guard frame.width > 0 else { return max(scaleFactor, 1) }
        return pixelSize.width / frame.width
    }

    var pixelsPerPointY: CGFloat {
        guard frame.height > 0 else { return max(scaleFactor, 1) }
        return pixelSize.height / frame.height
    }

    var localVisibleFrame: CGRect {
        CGRect(
            x: visibleFrame.minX - frame.minX,
            y: visibleFrame.minY - frame.minY,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }

    func pointToLocalPixel(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - frame.minX) * pixelsPerPointX,
            y: (point.y - frame.minY) * pixelsPerPointY
        )
    }

    func localPixelToPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: frame.minX + point.x / pixelsPerPointX,
            y: frame.minY + point.y / pixelsPerPointY
        )
    }

    func usableLocalPixelFrame(edgePadding: CGFloat) -> CGRect {
        let localPixelFrame = CGRect(
            x: localVisibleFrame.minX * pixelsPerPointX,
            y: localVisibleFrame.minY * pixelsPerPointY,
            width: localVisibleFrame.width * pixelsPerPointX,
            height: localVisibleFrame.height * pixelsPerPointY
        )

        let insetX = min(edgePadding * pixelsPerPointX, max(0, localPixelFrame.width / 2 - 1))
        let insetY = min(edgePadding * pixelsPerPointY, max(0, localPixelFrame.height / 2 - 1))
        return localPixelFrame.insetBy(dx: insetX, dy: insetY)
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
    private var lastModifierTap: (shortcut: SpecialShortcut, timestamp: CFAbsoluteTime)?

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

        let eventMask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue))
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
        if eventType == .flagsChanged {
            handleModifierEvent(event)
            return
        }

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

    private func handleModifierEvent(_ event: CGEvent) {
        guard let configuredShortcut = toggleShortcutProvider()?.specialShortcut,
              let detectedShortcut = specialShortcut(from: event) else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if let lastTap = lastModifierTap,
           lastTap.shortcut == configuredShortcut,
           detectedShortcut == configuredShortcut,
           now - lastTap.timestamp <= 0.35 {
            lastModifierTap = nil
            Task { @MainActor in
                onToggleMatch()
            }
        } else {
            lastModifierTap = detectedShortcut == configuredShortcut ? (configuredShortcut, now) : nil
        }
    }

    private func specialShortcut(from event: CGEvent) -> SpecialShortcut? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let activeFlags = event.flags.intersection(ModifierMask.relevantCGFlags)

        switch keyCode {
        case 54, 
            55 where activeFlags == .maskCommand:
            return .doubleCommand
        case 59, 
            
            62 where activeFlags == .maskControl:
            return .doubleControl
        case 58, 
            61 where activeFlags == .maskAlternate:
            return .doubleOption
        default:
            return nil
        }
    }
}

enum ScreenJumpService {
    @discardableResult
    static func jumpCursor(to target: DisplayShortcut, from source: DisplayShortcut?, currentLocation: CGPoint) -> (error: CGError, targetPoint: CGPoint) {
        let targetPoint: CGPoint
        if let source, source.frame.width > 0, source.frame.height > 0 {
            // 按鼠标在当前屏幕内的 xy 百分比位置，等比定位到目标屏幕
            let ratioX = min(max((currentLocation.x - source.frame.minX) / source.frame.width, 0), 1)
            let ratioY = min(max((currentLocation.y - source.frame.minY) / source.frame.height, 0), 1)
            targetPoint = CGPoint(
                x: target.frame.minX + ratioX * target.frame.width,
                y: target.frame.minY + ratioY * target.frame.height
            )
        } else {
            targetPoint = CGPoint(x: target.frame.midX, y: target.frame.midY)
        }
        return (CGWarpMouseCursorPosition(targetPoint), targetPoint)
    }
}

@MainActor
final class ScreenOverlayManager {
    private var windows: [CGDirectDisplayID: NSPanel] = [:]
    private var cursorIndicatorPanel: NSPanel?
    private var cursorRestoreTask: Task<Void, Never>?
    private var hiddenCursorDisplayID: CGDirectDisplayID?
    private var pointerStyleIndex = 0
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

    func showCursorIndicator(on display: DisplayShortcut, at point: CGPoint) {
        dismissCursorIndicator()

        // 每次切换屏幕轮换一种指针样式，让变化更显眼
        pointerStyleIndex = (pointerStyleIndex + 1) % CursorPointerStyle.allCases.count
        let style = CursorPointerStyle.allCases[pointerStyleIndex]

        // 隐藏系统指针，用自定义图片指针替代，方便看清落点位置
        CGDisplayHideCursor(display.displayID)
        hiddenCursorDisplayID = display.displayID

        let panelSize = CGSize(width: 160, height: 160)

        // CGEvent 使用左上角原点（Y 向下），AppKit 使用左下角原点（Y 向上），需转换
        let primaryScreenHeight = NSScreen.main?.frame.height ?? display.frame.height
        let appKitPoint = CGPoint(x: point.x, y: primaryScreenHeight - point.y)

        var origin = CGPoint(x: appKitPoint.x - panelSize.width / 2, y: appKitPoint.y - panelSize.height / 2)
        origin.x = min(max(origin.x, display.frame.minX), max(display.frame.minX, display.frame.maxX - panelSize.width))
        origin.y = min(max(origin.y, display.frame.minY), max(display.frame.minY, display.frame.maxY - panelSize.height))

        let panel = NSPanel(
            contentRect: CGRect(origin: origin, size: panelSize),
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

        // anchor 是相对于 panel contentView 的 SwiftUI 坐标（左上角原点，Y 向下）
        let anchor = CGPoint(
            x: appKitPoint.x - origin.x,
            y: panelSize.height - (appKitPoint.y - origin.y)
        )
        panel.contentView = NSHostingView(rootView: CursorIndicatorView(style: style, anchor: anchor))
        panel.orderFrontRegardless()
        cursorIndicatorPanel = panel

        // 鼠标一旦移动即移除图片指针；若未移动，1 秒后自动恢复系统指针
        cursorRestoreTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(1)
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                if Task.isCancelled { break }
                let location = CGEvent(source: nil)?.location ?? .zero
                let moved = abs(location.x - point.x) > 2 || abs(location.y - point.y) > 2
                if moved || Date() >= deadline {
                    break
                }
            }
            self?.dismissCursorIndicator()
        }
    }

    private func dismissCursorIndicator() {
        cursorRestoreTask?.cancel()
        cursorRestoreTask = nil
        cursorIndicatorPanel?.orderOut(nil)
        cursorIndicatorPanel = nil
        if let displayID = hiddenCursorDisplayID {
            CGDisplayShowCursor(displayID)
            hiddenCursorDisplayID = nil
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

private enum CursorIndicatorMetrics {
    static let pointerSize = CGSize(width: 54, height: 72)
    static let initialScale: CGFloat = 0.88
    static let visibleScale: CGFloat = 1.28
    /// 指针尖端在 MousePointerShape 内的比例位置（与 path 起点一致）
    static let tipRatio = CGPoint(x: 0.16, y: 0.06)
}

/// 切换屏幕时使用的图片指针样式，每次跳转轮换
private enum CursorPointerStyle: CaseIterable {
    case highlightYellow
    case oceanBlue
    case mintGreen
    case coralPink

    var fill: Color {
        switch self {
        case .highlightYellow:
            return Color(red: 1.0, green: 0.84, blue: 0.2)
        case .oceanBlue:
            return Color(red: 0.35, green: 0.78, blue: 1.0)
        case .mintGreen:
            return Color(red: 0.42, green: 0.9, blue: 0.62)
        case .coralPink:
            return Color(red: 1.0, green: 0.51, blue: 0.55)
        }
    }

    var stroke: Color {
        .black.opacity(0.45)
    }

    var halo: Color {
        fill.opacity(0.9)
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
    let style: CursorPointerStyle
    let anchor: CGPoint

    @State private var pointerScale: CGFloat = CursorIndicatorMetrics.initialScale
    @State private var pointerOpacity: Double = 0
    @State private var haloScale: CGFloat = 0.4
    @State private var haloOpacity: Double = 0.9

    var body: some View {
        let tipLocal = CGPoint(
            x: CursorIndicatorMetrics.pointerSize.width * CursorIndicatorMetrics.tipRatio.x,
            y: CursorIndicatorMetrics.pointerSize.height * CursorIndicatorMetrics.tipRatio.y
        )

        ZStack {
            // 落点位置的高亮圆圈，扩散后淡出，方便定位
            Circle()
                .stroke(style.halo, lineWidth: 3)
                .frame(width: 48, height: 48)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)
                .position(anchor)

            MousePointerShape()
                .fill(style.fill)
                .overlay {
                    MousePointerShape()
                        .stroke(style.stroke, lineWidth: 3)
                }
                .shadow(color: style.fill.opacity(0.55), radius: 10, x: 0, y: 4)
                .frame(width: CursorIndicatorMetrics.pointerSize.width, height: CursorIndicatorMetrics.pointerSize.height)
                .scaleEffect(pointerScale, anchor: .topLeading)
                .opacity(pointerOpacity)
                // 让指针尖端精确对准真实光标落点
                .offset(x: anchor.x - tipLocal.x, y: anchor.y - tipLocal.y)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
        }
        .onAppear {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                    pointerScale = CursorIndicatorMetrics.visibleScale
                    pointerOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.5)) {
                    haloScale = 1.8
                    haloOpacity = 0
                }
            }
    }
}

private struct MousePointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.86))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.minY + rect.height * 0.64))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 0.94))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.88))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.51, y: rect.minY + rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.58))
        path.closeSubpath()
        return path
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
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var hideInDockAtLaunchEnabled = false

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
    private var activationObserver: NSObjectProtocol?
    private var approvalPollTask: Task<Void, Never>?
    private var hasStarted = false
    private let previewMode: Bool
    private var shouldAutoRestartAfterPermissionGrant = false
    private var lastActiveDisplayID: CGDirectDisplayID?

    private static let shortcutsStorageKey = "mouseDance.screenShortcuts"
    private static let toggleShortcutStorageKey = "mouseDance.toggleShortcut"
    static let hideInDockAtLaunchStorageKey = "mouseDance.hideInDockAtLaunch"

    init(previewMode: Bool = false) {
        self.previewMode = previewMode
        self.screenShortcuts = Self.loadScreenShortcuts()
        self.toggleShortcut = Self.loadToggleShortcut() ?? Self.defaultToggleShortcut
        self.launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        self.hideInDockAtLaunchEnabled = UserDefaults.standard.bool(forKey: Self.hideInDockAtLaunchStorageKey)

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

    /// 开机自启动开关绑定
    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { self.launchAtLoginEnabled },
            set: { self.setLaunchAtLogin($0) }
        )
    }

    func refreshLaunchAtLoginState() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !previewMode else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            statusMessage = enabled
                ? "已开启开机自启动，登录后 MouseDance 将自动在菜单栏运行。"
                : "已关闭开机自启动。"
        } catch {
            statusMessage = (enabled ? "开启" : "关闭") + "开机自启动失败：\(error.localizedDescription)"
        }
        refreshLaunchAtLoginState()
    }

    /// 启动默认在程序坞隐藏开关绑定
    var hideInDockAtLaunchBinding: Binding<Bool> {
        Binding(
            get: { self.hideInDockAtLaunchEnabled },
            set: { self.setHideInDockAtLaunch($0) }
        )
    }

    func setHideInDockAtLaunch(_ enabled: Bool) {
        guard !previewMode else { return }
        hideInDockAtLaunchEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.hideInDockAtLaunchStorageKey)
        // 立即切换激活策略，让本次运行也生效；下次启动时会按偏好隐藏程序坞图标
        // （菜单栏图标被系统隐藏时会回退 regular，避免 macOS 26 的进程回收缺陷）
        AppDelegate.applyAccessoryPreference(enabled)
        if enabled && AppDelegate.menuBarItemHiddenBySystem {
            statusMessage = "菜单栏图标当前被系统隐藏，为保持应用稳定运行已暂时保留程序坞图标；图标恢复可见后将自动应用隐藏程序坞偏好。"
        } else {
            statusMessage = enabled
                ? "已开启启动默认在程序坞隐藏，下次启动将不显示程序坞图标，主窗口仍会正常打开。"
                : "已关闭启动默认在程序坞隐藏，下次启动将恢复显示程序坞图标。"
        }
    }

    func start() {
        guard !previewMode else { return }
        guard !hasStarted else { return }
        hasStarted = true

        refreshScreens(updateStatus: false)
        refreshPermissionState(startMonitor: true)
        if !inputMonitoringGranted {
            // 新版本安装后系统会重置输入监控授权，启动时给出明确引导
            statusMessage = "尚未获得输入监控权限（升级新版后系统会重置授权）。请点击菜单栏图标 →「前往授权…」重新开启，后台全局快捷键才能生效。"
        }

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

        // 全局监听应用激活：从系统设置授权返回时，即使主窗口未打开也能自动重检权限
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshInputMonitoringState()
                self?.refreshLaunchAtLoginState()
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
                AppDelegate.applyAccessoryPreference(true)
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
        startApprovalPolling()
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

    /// 授权等待期间轮询检测授权状态，避免用户授权后应用无法感知
    private func startApprovalPolling() {
        stopApprovalPolling()
        approvalPollTask = Task { @MainActor [weak self] in
            // 最多轮询约 90 秒，每 1.5 秒检测一次
            for _ in 0..<60 {
                try? await Task.sleep(for: .seconds(1.5))
                guard let self, !Task.isCancelled else { return }
                if GlobalHotKeyMonitor.hasPermission() {
                    self.refreshPermissionState(startMonitor: true)
                    if self.inputMonitoringGranted {
                        self.statusMessage = "输入监控权限已可用，全局快捷键已恢复。"
                    }
                    return
                }
            }
            self?.stopApprovalPolling()
        }
    }

    private func stopApprovalPolling() {
        approvalPollTask?.cancel()
        approvalPollTask = nil
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
        let sourceDisplay = displays.first(where: { $0.frame.contains(currentLocation) })

        if sourceDisplay?.displayID == display.displayID {
            statusMessage = "鼠标已在当前屏幕：\(display.name)。"
            return
        }

        if let sourceDisplay {
            lastActiveDisplayID = sourceDisplay.displayID
        }

        let jumpResult = ScreenJumpService.jumpCursor(to: display, from: sourceDisplay, currentLocation: currentLocation)
        if jumpResult.error == .success {
            overlayManager.showCursorIndicator(on: display, at: jumpResult.targetPoint)
            statusMessage = "鼠标已跳转到屏幕：\(display.name)。"
        } else {
            statusMessage = "鼠标跳转失败，系统返回：\(jumpResult.error.rawValue)。"
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

    private static var defaultToggleShortcut: ShortcutKey {
        .doubleCommand
    }

    private func refreshPermissionState(startMonitor: Bool) {
        let wasGranted = inputMonitoringGranted
        inputMonitoringGranted = GlobalHotKeyMonitor.hasPermission()
        inputMonitoringStatus = resolvedInputMonitoringStatus()
        if inputMonitoringGranted {
            stopApprovalPolling()
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
