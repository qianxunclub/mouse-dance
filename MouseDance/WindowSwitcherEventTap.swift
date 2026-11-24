import AppKit
import CoreGraphics
import Foundation

/// 默认 MainActor 隔离下，全局 let 也会被隔离；事件 tap 线程是 nonisolated，
/// 因此把这些常量放进 nonisolated 类型里。
nonisolated enum SwitcherKeyCodes {
    static let tab: CGKeyCode = 48
    static let escape: CGKeyCode = 53
    static let `return`: CGKeyCode = 36
    static let enter: CGKeyCode = 76
    static let numberIndex: [CGKeyCode: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4,
        22: 5, 26: 6, 28: 7, 25: 8, 29: 9
    ]
}

// MARK: - 会话状态机

/// 事件 tap 回调跑在专用线程上，不能触碰任何 MainActor 状态。
/// 这里只保存一份用 NSLock 保护的纯值状态，并同步给出「放行 / 吞掉 + 动作」的结论。
/// 触发键固定为 ⌘Tab（完全接管系统切换器）。
nonisolated final class SwitcherTapSession: @unchecked Sendable {
    private let lock = NSLock()
    private var active = false

    func reset() {
        lock.lock()
        active = false
        lock.unlock()
    }

    private func setActive(_ value: Bool) {
        lock.lock()
        active = value
        lock.unlock()
    }

    func decide(type: CGEventType, event: CGEvent) -> SwitcherTapAction {
        lock.lock()
        let active = self.active
        lock.unlock()

        let flags = event.flags
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if type == .flagsChanged {
            // 松开 Command = 确认选择，这是 ⌘Tab 的原生手感
            if active, !flags.contains(.maskCommand) {
                setActive(false)
                return .commit
            }
            return active ? .swallow : .pass
        }

        guard type == .keyDown || type == .keyUp else {
            return active ? .swallow : .pass
        }

        if active {
            // 会话期间吞掉所有按键，避免 ⌘S、⌘Q 等误触下层应用
            guard type == .keyDown else { return .swallow }
            switch keyCode {
            case SwitcherKeyCodes.tab:
                return flags.contains(.maskShift) ? .previous : .next
            case SwitcherKeyCodes.escape:
                setActive(false)
                return .cancel
            case SwitcherKeyCodes.return, SwitcherKeyCodes.enter:
                setActive(false)
                return .commit
            case 123, 126:
                return .previous
            case 124, 125:
                return .next
            default:
                if let index = SwitcherKeyCodes.numberIndex[keyCode] { return .select(index) }
                return .swallow
            }
        }

        guard type == .keyDown else { return .pass }

        let matches = flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)
            && keyCode == SwitcherKeyCodes.tab
        guard matches else { return .pass }

        setActive(true)
        return .arm
    }
}

// MARK: - 全局事件 tap

/// 会话级 `.defaultTap`：可以修改 / 丢弃事件，因此能真正替换系统 ⌘Tab。
/// tap 挂在独立线程的 RunLoop 上，主线程渲染面板不会让热键超时失效。
nonisolated final class SwitcherEventTap: @unchecked Sendable {
    private let session = SwitcherTapSession()
    private let lock = NSLock()

    nonisolated(unsafe) private var tap: CFMachPort?
    nonisolated(unsafe) private var source: CFRunLoopSource?
    nonisolated(unsafe) private var runLoop: CFRunLoop?
    private var thread: Thread?

    /// 回调在 tap 线程上触发；实现方需自行派发回 MainActor。
    nonisolated(unsafe) var onAction: (@Sendable (SwitcherTapAction) -> Void)?

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return tap != nil
    }

    func start() {
        guard !isRunning else { return }
        session.reset()
        let worker = Thread { [weak self] in
            guard let self, self.installTap() else { return }
            CFRunLoopRun()
        }
        worker.name = "com.qianxunclub.MouseDance.switcher-eventtap"
        worker.stackSize = 512 * 1024
        thread = worker
        worker.start()
    }

    /// 必须在该专用线程上调用
    private func installTap() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<SwitcherEventTap>
                    .fromOpaque(info)
                    .takeUnretainedValue()

                // tap 被系统临时禁用（超时或用户输入）时立刻重新启用，避免热键静默死亡
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    monitor.reenable()
                    return Unmanaged.passUnretained(event)
                }

                let action = monitor.session.decide(type: type, event: event)
                // 只把有意义的动作派发回主线程；pass / swallow 无需创建 Task
                switch action {
                case .pass:
                    return Unmanaged.passUnretained(event)
                case .swallow:
                    return nil
                case .commit where type == .flagsChanged:
                    monitor.onAction?(action)
                    // Command 松开的事件要放行：吞掉会让系统以为 Command 仍被按住
                    return Unmanaged.passUnretained(event)
                default:
                    monitor.onAction?(action)
                    return nil
                }
            },
            userInfo: userInfo
        ) else { return false }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(nil, created, 0) else {
            CFMachPortInvalidate(created)
            return false
        }

        let currentRunLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(currentRunLoop, runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)

        lock.lock()
        tap = created
        source = runLoopSource
        runLoop = currentRunLoop
        lock.unlock()

        // 只有 tap 确实安装成功才接管系统符号热键；若因权限不足创建失败，
        // 系统原生 ⌘Tab 会保持可用，不会变成「按了完全没反应」。
        SystemHotKeyOverride.setCommandTab(enabled: false)
        return true
    }

    private func reenable() {
        lock.lock()
        let current = tap
        lock.unlock()
        if let current { CGEvent.tapEnable(tap: current, enable: true) }
    }

    func stop() {
        lock.lock()
        let currentTap = tap
        let currentSource = source
        let currentRunLoop = runLoop
        tap = nil
        source = nil
        runLoop = nil
        lock.unlock()

        if let currentSource, let currentRunLoop {
            CFRunLoopRemoveSource(currentRunLoop, currentSource, .commonModes)
        }
        if let currentTap {
            CGEvent.tapEnable(tap: currentTap, enable: false)
            CFMachPortInvalidate(currentTap)
        }
        if let currentRunLoop { CFRunLoopStop(currentRunLoop) }
        session.reset()
        SystemHotKeyOverride.setCommandTab(enabled: true)
        onAction = nil
        thread = nil
    }
}
