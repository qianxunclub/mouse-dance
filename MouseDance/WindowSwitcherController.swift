import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation
import SwiftUI

/// 窗口切换器的总编排：权限、事件 tap、窗口枚举、面板、聚焦。
/// 只有一个开关（isEnabled），其余行为全部固定：完全接管 ⌘Tab、
/// 只列当前屏幕可见窗口、不显示缩略图。
@MainActor
final class WindowSwitcherController: ObservableObject {
    @Published var isEnabled = false { didSet { save(); apply() } }

    @Published private(set) var accessibilityGranted = false

    private let eventTap = SwitcherEventTap()
    private let panel = SwitcherPanelController()

    private var windows: [SwitcherWindow] = []
    private var selectedIndex = 0
    private var isSessionActive = false
    private var listReady = false
    private var pendingDelta = 0
    private var pendingSelection: Int?
    private var pendingCommit = false
    private var sessionGeneration = 0
    private var recentWindowIDs: [CGWindowID] = []
    private var hasStarted = false
    private var observers: [NSObjectProtocol] = []

    private enum Key {
        static let enabled = "mouseDance.switcher.enabled"
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Key.enabled)
    }

    // MARK: - 生命周期

    func start() {
        refreshPermissions()
        apply()

        guard !hasStarted else { return }
        hasStarted = true

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshPermissions()
                self?.apply()
            }
        })

        // 无论正常退出还是被系统回收，都把系统 ⌘Tab 还回去
        observers.append(center.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.prepareForTermination() }
        })
    }

    func prepareForTermination() {
        cancel()
        eventTap.stop()
        SystemHotKeyOverride.setCommandTab(enabled: true)
    }

    // MARK: - 权限

    func refreshPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacySettings(pane: "Privacy_Accessibility")
    }

    private func openPrivacySettings(pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"),
           NSWorkspace.shared.open(url) { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 事件开关

    private func apply() {
        guard isEnabled, accessibilityGranted else {
            eventTap.stop()
            SystemHotKeyOverride.setCommandTab(enabled: true)
            return
        }

        eventTap.onAction = { [weak self] action in
            guard let self else { return }
            Task { @MainActor in self.handle(action) }
        }
        // 符号热键的开关由 SwitcherEventTap 在 tap 安装成功后自行接管，
        // 安装失败时保持系统 ⌘Tab 可用（见 installTap / stop）。
        eventTap.start()
    }

    // MARK: - 会话

    private func handle(_ action: SwitcherTapAction) {
        switch action {
        case .pass, .swallow:
            break
        case .arm:
            arm()
        case .next:
            move(1)
        case .previous:
            move(-1)
        case .select(let index):
            select(index)
        case .commit:
            commit()
        case .cancel:
            cancel()
        }
    }

    private func arm() {
        sessionGeneration &+= 1
        let generation = sessionGeneration

        isSessionActive = true
        listReady = false
        windows = []
        selectedIndex = 0
        pendingDelta = 0
        pendingSelection = nil
        pendingCommit = false
        refreshPermissions()

        let apps = Self.runningAppInfo()
        let recent = recentWindowIDs

        Task { @MainActor [weak self] in
            // 枚举放在 detached 任务里，AX 遍历不会阻塞主线程
            let list = await Task.detached(priority: .userInitiated) {
                WindowEnumerator.collect(apps: apps)
            }.value

            guard let self, self.sessionGeneration == generation else { return }
            // 严格按窗口级 MRU 排序，不再按 App 分组或把当前前台 App 的窗口整体提前
            let ordered = Self.order(list, recent: recent)
            self.windows = ordered
            self.listReady = true

            // 首次使用时把当前最前窗口记为 MRU 栈顶。此后每次提交只把选中的
            // 那个窗口移到栈顶，于是列表第 1 项＝当前窗口、第 2 项＝上一个窗口，
            // 实现真正的窗口级来回切换，而不是按 App 整组挪动。
            if self.recentWindowIDs.isEmpty {
                let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
                let current = ordered.first { $0.ownerPID == frontmostPID } ?? ordered.first
                if let current { self.recentWindowIDs.append(current.id) }
            }

            guard !ordered.isEmpty else {
                if self.isSessionActive {
                    self.panel.show(
                        windows: [], selectedIndex: 0, appIcons: [:],
                        onSelect: { [weak self] index in self?.select(index) },
                        onCancel: { [weak self] in self?.cancel() }
                    )
                }
                return
            }

            // 枚举完成前到达的 Tab / 点击在这里一次性结算
            let initial = ordered.count > 1 ? 1 : 0
            let index: Int
            if let pending = self.pendingSelection {
                index = min(max(pending, 0), ordered.count - 1)
            } else {
                index = Self.wrap(initial + self.pendingDelta, count: ordered.count)
            }
            self.selectedIndex = index

            if self.pendingCommit {
                self.isSessionActive = false
                self.commitFocus()
                return
            }
            guard self.isSessionActive else { return }

            self.panel.show(
                windows: ordered,
                selectedIndex: index,
                appIcons: Self.icons(for: ordered),
                onSelect: { [weak self] selected in self?.select(selected) },
                onCancel: { [weak self] in self?.cancel() }
            )
        }
    }

    private func move(_ delta: Int) {
        guard isSessionActive else { return }
        if listReady, !windows.isEmpty {
            selectedIndex = Self.wrap(selectedIndex + delta, count: windows.count)
            panel.setSelectedIndex(selectedIndex)
        } else {
            pendingDelta += delta
            pendingSelection = nil
        }
    }

    private func select(_ index: Int) {
        guard isSessionActive else { return }
        if listReady, windows.indices.contains(index) {
            selectedIndex = index
            commit()
        } else {
            pendingSelection = index
            pendingCommit = true
            isSessionActive = false
            panel.hide()
        }
    }

    private func commit() {
        guard isSessionActive else { return }
        isSessionActive = false
        panel.hide()
        // 窗口枚举是异步的：若此刻列表还没就绪，等枚举完成后再执行聚焦，
        // 否则会静默什么都不做（这正是「选中的窗口没跳过去」的根因）。
        if listReady {
            commitFocus()
        } else {
            pendingCommit = true
        }
    }

    private func commitFocus() {
        guard windows.indices.contains(selectedIndex) else { return }
        let target = windows[selectedIndex]
        recentWindowIDs.removeAll { $0 == target.id }
        recentWindowIDs.insert(target.id, at: 0)
        if recentWindowIDs.count > 32 { recentWindowIDs.removeLast() }
        focus(target, attempt: 0)
    }

    /// App 激活与 AX 提窗分开做，并在随后按递增间隔校验、必要时重试：
    /// macOS 的激活是异步的，窗口所属 Space 切换也需要时间。
    private func focus(_ window: SwitcherWindow, attempt: Int) {
        if let app = NSRunningApplication(processIdentifier: window.ownerPID) {
            app.unhide()
            app.activate()
        }
        // AX 调用带 0.3s 超时，放到后台线程，避免某个卡住的 App 阻塞主线程
        Task.detached(priority: .userInitiated) {
            _ = WindowActivator.shared.raise(window: window)
        }

        guard attempt < 4 else { return }
        let delays: [UInt64] = [80, 160, 320, 560] // 毫秒
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delays[attempt] * 1_000_000)
            guard let self, !self.isSessionActive else { return }
            let frontmostOK = NSWorkspace.shared.frontmostApplication?.processIdentifier == window.ownerPID
            let mainOK = await Task.detached(priority: .userInitiated) {
                WindowActivator.shared.mainWindowID(pid: window.ownerPID) == window.id
            }.value
            if frontmostOK && mainOK { return }
            self.focus(window, attempt: attempt + 1)
        }
    }

    private func cancel() {
        isSessionActive = false
        pendingCommit = false
        pendingSelection = nil
        pendingDelta = 0
        panel.hide()
    }

    // MARK: - 辅助方法

    private static func runningAppInfo() -> [pid_t: SwitcherAppInfo] {
        var result: [pid_t: SwitcherAppInfo] = [:]
        for app in NSWorkspace.shared.runningApplications {
            result[app.processIdentifier] = SwitcherAppInfo(
                name: app.localizedName ?? app.bundleIdentifier ?? "未知应用",
                bundleIdentifier: app.bundleIdentifier,
                isRegular: app.activationPolicy != .prohibited
            )
        }
        return result
    }

    private static func icons(for windows: [SwitcherWindow]) -> [pid_t: NSImage] {
        var icons: [pid_t: NSImage] = [:]
        for pid in Set(windows.map(\.ownerPID)) {
            if let icon = NSRunningApplication(processIdentifier: pid)?.icon {
                icons[pid] = icon
            }
        }
        return icons
    }

    /// 纯「窗口级」最近使用顺序：recent 数组越靠前的窗口越靠前，
    /// 从未使用过的窗口按 z-order 兜底。不按 App 分组，也不会因为切到某个 App
    /// 就把它的所有窗口一起挪到最前。
    /// 面板默认选中第 2 项，即「上一次使用的那个窗口」，贴合 Alt+Tab 的肌肉记忆。
    private static func order(
        _ list: [SwitcherWindow],
        recent: [CGWindowID]
    ) -> [SwitcherWindow] {
        var rank: [CGWindowID: Int] = [:]
        for (offset, id) in recent.enumerated() where rank[id] == nil {
            rank[id] = offset
        }
        let tail = recent.count
        return list.sorted { lhs, rhs in
            let l = rank[lhs.id] ?? tail
            let r = rank[rhs.id] ?? tail
            if l != r { return l < r }
            return lhs.order < rhs.order
        }
    }

    private static func wrap(_ value: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (value % count + count) % count
    }

    private func save() {
        UserDefaults.standard.set(isEnabled, forKey: Key.enabled)
    }
}
