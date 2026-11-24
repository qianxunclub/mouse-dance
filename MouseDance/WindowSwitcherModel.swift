import AppKit
import CoreGraphics
import Darwin
import Foundation

// MARK: - 窗口快照

/// 一次枚举得到的窗口快照。全部为值类型，可安全跨越线程与 actor 边界。
struct SwitcherWindow: Identifiable, Hashable, Sendable {
    let id: CGWindowID
    let ownerPID: pid_t
    let appName: String
    let title: String
    /// CG 全局坐标（左上角原点，Y 向下），仅用于提交时 AX 元素的兜底匹配
    let bounds: CGRect
    /// CGWindowList 返回的自前后顺序，用于兜底排序
    let order: Int
}

/// 在 MainActor 侧预先取好的应用信息，避免后台枚举接触 AppKit。
struct SwitcherAppInfo: Sendable {
    let name: String
    let bundleIdentifier: String?
    let isRegular: Bool
}

// MARK: - 事件动作

nonisolated enum SwitcherTapAction: Sendable {
    case pass
    case swallow
    case arm
    case next
    case previous
    case commit
    case cancel
    case select(Int)
}

// MARK: - 系统符号热键（可选增强）

/// ⌘Tab / ⌘⇧Tab 在系统里是编号 1 / 2 的 symbolic hotkey。
/// 关闭后即使事件 tap 偶发漏掉按键，系统原生切换器也不会弹出。
/// 通过 dlsym 动态查找：找不到符号时静默跳过，事件 tap 仍会兜底拦截。
nonisolated enum SystemHotKeyOverride {
    private typealias SetEnabled = @convention(c) (UInt32, Bool) -> Int32

    /// RTLD_DEFAULT = (void *)-2，Swift 未直接导出该常量
    private static let globalHandle = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: -2))

    private static let setter: SetEnabled? = {
        if let symbol = dlsym(globalHandle, "CGSSetSymbolicHotKeyEnabled") {
            return unsafeBitCast(symbol, to: SetEnabled.self)
        }
        let candidates = [
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
        ]
        for path in candidates {
            guard let handle = dlopen(path, RTLD_NOW),
                  let symbol = dlsym(handle, "CGSSetSymbolicHotKeyEnabled") else { continue }
            return unsafeBitCast(symbol, to: SetEnabled.self)
        }
        return nil
    }()

    /// 该开关是进程级运行时标记，进程退出后系统会自动恢复；这里仍显式调用，
    /// 保证关闭功能或退出应用时立即归还系统快捷键。
    static func setCommandTab(enabled: Bool) {
        guard let setter else { return }
        _ = setter(1, enabled)
        _ = setter(2, enabled)
    }
}
