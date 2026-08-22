import SwiftUI

enum MouseDanceWindowIdentifier {
    static let main = "main"
    static let update = "update"
}

@main
struct MouseDanceApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = MouseDanceStore()
    @StateObject private var updateManager = UpdateManager()

    var body: some Scene {
        Window("MouseDance", id: MouseDanceWindowIdentifier.main) {
            ContentView()
                .environmentObject(store)
                .environmentObject(updateManager)
                .task {
                    store.start()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
                    if let window = notification.object as? NSWindow {
                        window.standardWindowButton(.zoomButton)?.isHidden = true
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    }
                }
        }
        // 仅登录自启动时抑制主窗口；普通打开（含程序坞隐藏模式）应正常显示主窗口
        .defaultLaunchBehavior(appDelegate.launchedAsLoginItem ? .suppressed : .automatic)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)

        MenuBarExtra {
            menuContent
        } label: {
            menuBarLabel
                // 登录自启动时主窗口被抑制，ContentView 的 .task 不会执行，
                // 在这里保证快捷键监听照常启动（start 内部幂等）。
                .task {
                    store.start()
                    // 静默检查一次更新，让主窗口「版本与更新」区能直接显示可更新目标版本
                    await updateManager.checkForUpdates()
                }
        }

        Window("MouseDance 更新", id: MouseDanceWindowIdentifier.update) {
            UpdateView(manager: updateManager)
        }
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("MouseDance")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(store.inputMonitoringGranted ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Divider()
                .padding(.vertical, 4)

            Button {
                store.relabelScreens()
            } label: {
                Label("在屏幕上显示当前配置", systemImage: "rectangle.grid.3x2")
            }

            Divider()
                .padding(.vertical, 4)

            if store.displays.isEmpty {
                Text("暂无可跳转屏幕")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            } else {
                Text("快捷跳转")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)

                ForEach(store.displays) { display in
                    Button {
                        store.jumpToDisplay(display)
                    } label: {
                        HStack {
                            Label {
                                Text(display.name)
                                    .lineLimit(1)
                            } icon: {
                                Image(systemName: "display")
                            }

                            Spacer()

                            if let shortcut = store.screenShortcuts[display.displayID] {
                                Text(shortcut.displayName)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("未设置")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            Button {
                store.setLaunchAtLogin(!store.launchAtLoginEnabled)
            } label: {
                Label(
                    store.launchAtLoginEnabled ? "开机自启动：已开启" : "开机自启动：已关闭",
                    systemImage: store.launchAtLoginEnabled ? "checkmark.circle.fill" : "circle"
                )
            }

            Divider()
                .padding(.vertical, 4)

            Button {
                openMainWindow()
            } label: {
                Label("打开主窗口", systemImage: "window.vertical.closed")
            }

            Divider()
                .padding(.vertical, 4)

            Button {
                Task { await updateManager.checkForUpdates() }
                openWindow(id: MouseDanceWindowIdentifier.update)
            } label: {
                Label("检查更新…", systemImage: "arrow.triangle.2.circlepath")
            }

            Divider()
                .padding(.vertical, 4)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出 MouseDance", systemImage: "xmark.square")
            }
        }
        .padding(.vertical, 8)
        .frame(width: 280)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "cursorarrow.motionlines")
                .imageScale(.medium)
                .foregroundStyle(store.inputMonitoringGranted ? .primary : .secondary)
        }
    }

    private func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: MouseDanceWindowIdentifier.main)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 是否为系统登录时自动拉起
    private(set) var launchedAsLoginItem = false

    /// macOS 26 中控制中心会把菜单栏图标可见性写进应用 UserDefaults，
    /// 键形如 "NSStatusItem Visible Item-N" / "NSStatusItem VisibleCC Item-N"
    private static let statusItemVisibilityKeyPrefix = "NSStatusItem Visible"

    /// 运行时轮询图标可见性变化（系统可能在运行期间随时改写）
    private var accessoryWatchdog: Timer?

    /// 菜单栏图标是否被系统隐藏
    static var menuBarItemHiddenBySystem: Bool {
        let defaults = UserDefaults.standard
        return defaults.dictionaryRepresentation().keys.contains { key in
            key.hasPrefix(statusItemVisibilityKeyPrefix)
                && (defaults.object(forKey: key) as? NSNumber)?.boolValue == false
        }
    }

    /// 是否应以程序坞隐藏的菜单栏模式启动
    var shouldLaunchAsAccessory: Bool {
        launchedAsLoginItem
    }

    /// macOS 26 已知缺陷：MenuBarExtra + accessory 激活策略 + 菜单栏图标被系统隐藏
    /// 三者叠加时，SwiftUI 找不到可维持生命周期的有效 scene，进程会在启动瞬间被
    /// 优雅回收（exit 0、无崩溃日志）。因此仅当菜单栏图标可见时才允许切到 accessory，
    /// 否则回退 regular 保留程序坞图标，确保始终有可见锚点维持进程存活。
    static func applyAccessoryPreference(_ wantsAccessory: Bool) {
        let policy: NSApplication.ActivationPolicy =
            wantsAccessory && !menuBarItemHiddenBySystem ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchedAsLoginItem = Self.isLaunchedAsLoginItem()
        if shouldLaunchAsAccessory {
            // 以 accessory 模式运行，程序坞不显示图标
            Self.applyAccessoryPreference(true)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        startAccessoryWatchdog()
        guard launchedAsLoginItem else { return }
        Self.applyAccessoryPreference(true)
        // 兜底：登录自启动时若主窗口仍被创建则直接关闭
        for window in NSApp.windows where window.styleMask.contains(.titled) && !(window is NSPanel) {
            window.close()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        Self.applyAccessoryPreference(true)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    /// accessory 模式运行期间，系统仍可能随时隐藏菜单栏图标（控制中心改写可见性）。
    /// 每秒重评一次：图标被隐藏就切回 regular。
    private func startAccessoryWatchdog() {
        accessoryWatchdog?.invalidate()
        accessoryWatchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let hasVisibleMainWindow = NSApp.windows.contains { window in
                    window.isVisible
                        && window.styleMask.contains(.titled)
                        && !(window is NSPanel)
                }
                let wantsAccessory = !hasVisibleMainWindow
                    && (self.shouldLaunchAsAccessory || NSApp.activationPolicy() == .accessory)
                Self.applyAccessoryPreference(wantsAccessory)
            }
        }
    }

    /// 通过启动时收到的 AppleEvent 判断应用是否作为登录项被系统拉起
    private static func isLaunchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == fourCharCode("oapp") // kAEOpenApplication
        else { return false }
        return event.paramDescriptor(forKeyword: fourCharCode("prdt"))?.enumCodeValue
            == fourCharCode("lgik") // keyAELaunchedAsLogInItem
    }

    private static func fourCharCode(_ string: String) -> FourCharCode {
        string.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
    }
}
