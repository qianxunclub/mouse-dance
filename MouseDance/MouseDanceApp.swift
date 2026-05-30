import SwiftUI

@main
struct MouseDanceApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = MouseDanceStore()

    private enum WindowIdentifier {
        static let main = "main"
    }

    var body: some Scene {
        Window("MouseDance", id: WindowIdentifier.main) {
            ContentView()
                .environmentObject(store)
                .frame(width: 760, height: 430)
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
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        MenuBarExtra {
            menuContent
        } label: {
            menuBarLabel
        }
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
                openMainWindow()
            } label: {
                Label("打开主窗口", systemImage: "window.vertical.closed")
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
        openWindow(id: WindowIdentifier.main)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
}
