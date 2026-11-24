import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

// MARK: - 私有 API：AX 元素 ↔ CGWindowID

nonisolated enum AXWindowIDResolver {
    /// AXError _AXUIElementGetWindow(AXUIElementRef element, uint32_t *windowNumber)
    typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> Int32

    /// RTLD_DEFAULT = (void *)-2，Swift 未直接导出该常量
    private static let globalHandle = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: -2))

    static let function: GetWindow? = {
        if let symbol = dlsym(globalHandle, "_AXUIElementGetWindow") {
            return unsafeBitCast(symbol, to: GetWindow.self)
        }
        guard let handle = dlopen(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
            RTLD_NOW
        ), let symbol = dlsym(handle, "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(symbol, to: GetWindow.self)
    }()

    static func id(of element: AXUIElement) -> CGWindowID? {
        guard let function else { return nil }
        var number: UInt32 = 0
        guard function(element, &number) == 0, number != 0 else { return nil }
        return CGWindowID(number)
    }
}

// MARK: - 提窗

/// 保存 CGWindowID → AXUIElement 的映射。AX 元素本身不是 Sendable，
/// 因此集中放在这个 nonisolated 对象里用锁保护，不跨越 actor 边界传递。
nonisolated final class WindowActivator: @unchecked Sendable {
    static let shared = WindowActivator()

    private let lock = NSLock()
    private var axWindows: [CGWindowID: AXUIElement] = [:]

    func replaceCache(_ cache: [CGWindowID: AXUIElement]) {
        lock.lock()
        axWindows = cache
        lock.unlock()
    }

    private func cached(_ id: CGWindowID) -> AXUIElement? {
        lock.lock()
        defer { lock.unlock() }
        return axWindows[id]
    }

    /// 目标 App 当前的 AX 主窗口，用于确认切换是否真的生效。
    func mainWindowID(pid: pid_t) -> CGWindowID? {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.2)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &ref) == .success,
              let ref else { return nil }
        return AXWindowIDResolver.id(of: ref as! AXUIElement)
    }

    /// 把指定窗口提到最前。返回 false 表示连 AX 元素都没找到（此时至少已激活 App）。
    func raise(window: SwitcherWindow) -> Bool {
        guard let element = resolve(window: window) else { return false }
        AXUIElementSetMessagingTimeout(element, 0.3)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)

        let appElement = AXUIElementCreateApplication(window.ownerPID)
        AXUIElementSetMessagingTimeout(appElement, 0.3)
        // Electron / Java 类 App 只有同时设置 App 级属性才会真正换到目标窗口
        AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(appElement, kAXMainWindowAttribute as CFString, element)
        AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, element)
        return true
    }

    private func resolve(window: SwitcherWindow) -> AXUIElement? {
        if let cached = cached(window.id) { return cached }
        // 枚举期的缓存可能因窗口重建而失效，提交时按目标 App 重新查一遍
        return Self.freshResolve(window: window)
    }

    private static func freshResolve(window: SwitcherWindow) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(window.ownerPID)
        AXUIElementSetMessagingTimeout(appElement, 0.3)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let elements = windowsRef as? [AXUIElement] else { return nil }

        if let match = elements.first(where: { AXWindowIDResolver.id(of: $0) == window.id }) {
            return match
        }
        if !window.title.isEmpty {
            for element in elements {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String, title == window.title { return element }
            }
        }
        if window.bounds.width > 1, window.bounds.height > 1 {
            for element in elements {
                guard let frame = axFrame(element),
                      abs(frame.origin.x - window.bounds.origin.x) < 4,
                      abs(frame.origin.y - window.bounds.origin.y) < 4,
                      abs(frame.width - window.bounds.width) < 4,
                      abs(frame.height - window.bounds.height) < 4 else { continue }
                return element
            }
        }
        return elements.count == 1 ? elements[0] : nil
    }

    private static func axFrame(_ element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }
        let pos = posRef as! AXValue
        let size = sizeRef as! AXValue
        var point = CGPoint.zero
        var dimension = CGSize.zero
        guard AXValueGetValue(pos, .cgPoint, &point),
              AXValueGetValue(size, .cgSize, &dimension) else { return nil }
        return CGRect(origin: point, size: dimension)
    }
}

// MARK: - 窗口枚举

/// 完全在后台线程运行：只使用 CoreGraphics 的 C API 与 AX 的 C API，
/// 不接触任何 MainActor 隔离的 AppKit 状态。
nonisolated enum WindowEnumerator {
    private static let systemOwnerNames: Set<String> = [
        "Dock", "WindowServer", "ControlCenter", "NotificationCenter",
        "SystemUIServer", "loginwindow", "Spotlight", "WallpaperAgent",
        "Brightness Keys", "Universal Control", "Sidecar", "Screen Time"
    ]

    private static let systemBundles: Set<String> = [
        "com.apple.dock", "com.apple.controlcenter", "com.apple.notificationcenterui",
        "com.apple.systemuiserver", "com.apple.loginwindow", "com.apple.Spotlight",
        "com.apple.WindowServer"
    ]

    private struct Candidate {
        let windowID: CGWindowID
        let pid: pid_t
        let ownerName: String
        let cgTitle: String
        let bounds: CGRect
        let order: Int
    }

    /// 固定只枚举当前屏幕可见窗口（.optionOnScreenOnly）。
    /// 最小化窗口、其他 Space、隐藏 App 都不进入列表，聚焦因此始终可靠。
    static func collect(apps: [pid_t: SwitcherAppInfo]) -> [SwitcherWindow] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        let selfPID = ProcessInfo.processInfo.processIdentifier
        let selfBundle = Bundle.main.bundleIdentifier

        var candidates: [Candidate] = []
        candidates.reserveCapacity(list.count)

        for (order, info) in list.enumerated() {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != selfPID,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let number = info[kCGWindowNumber as String] as? Int else { continue }

            // 完全透明的窗口基本都是 tooltip / 隐藏辅助层
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha <= 0.01 { continue }

            let boundsDict = info[kCGWindowBounds as String] as? [String: Any]
            let bounds = boundsDict.flatMap { CGRect(dictionaryRepresentation: $0 as CFDictionary) } ?? .zero
            guard bounds.width >= 60, bounds.height >= 60 else { continue }

            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
            guard !systemOwnerNames.contains(ownerName) else { continue }
            if let appInfo = apps[pid] {
                guard appInfo.isRegular else { continue }
                if let bundle = appInfo.bundleIdentifier {
                    guard bundle != selfBundle, !systemBundles.contains(bundle) else { continue }
                }
            }

            candidates.append(Candidate(
                windowID: CGWindowID(number),
                pid: pid,
                ownerName: ownerName,
                cgTitle: info[kCGWindowName as String] as? String ?? "",
                bounds: bounds,
                order: order
            ))
        }

        var axCache: [CGWindowID: AXUIElement] = [:]
        var axTitles: [CGWindowID: String] = [:]

        // 每个进程只做一轮 AX 遍历，逐元素设超时，避免某个卡住的 App 拖慢整个面板
        for pid in Set(candidates.map(\.pid)) {
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appElement, 0.12)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let elements = windowsRef as? [AXUIElement] else { continue }

            for element in elements {
                AXUIElementSetMessagingTimeout(element, 0.12)
                guard let windowID = AXWindowIDResolver.id(of: element) else { continue }
                axCache[windowID] = element

                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String, !title.isEmpty {
                    axTitles[windowID] = title
                }
            }
        }

        WindowActivator.shared.replaceCache(axCache)

        var result: [SwitcherWindow] = []
        result.reserveCapacity(candidates.count)

        for candidate in candidates {
            let hasAX = axCache[candidate.windowID] != nil
            let title = axTitles[candidate.windowID] ?? candidate.cgTitle
            // 无标题且 AX 里也找不到对应窗口的大多是 tooltip、透明浮层
            guard hasAX || !title.isEmpty else { continue }

            let appName = apps[candidate.pid]?.name
                ?? (candidate.ownerName.isEmpty ? "未知应用" : candidate.ownerName)

            result.append(SwitcherWindow(
                id: candidate.windowID,
                ownerPID: candidate.pid,
                appName: appName,
                title: title.isEmpty ? appName : title,
                bounds: candidate.bounds,
                order: candidate.order
            ))
        }

        return result
    }
}
