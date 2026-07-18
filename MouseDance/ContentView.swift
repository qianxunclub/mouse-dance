import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject private var store: MouseDanceStore
    @State private var isRecordingToggle = false

    var body: some View {
        Form {
            Section {
                permissionRow

                HStack {
                    Label("快捷切换", systemImage: "keyboard")
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    ShortcutRecorderView(
                        shortcut: $store.toggleShortcut,
                        isRecording: $isRecordingToggle
                    )
                    .frame(width: 180, height: 24)
                }
                .frame(height: 24)

                HStack {
                    Label("开机自启动", systemImage: "power")

                    Spacer(minLength: 12)

                    Toggle("开机自启动", isOn: store.launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .frame(height: 24)
            } header: {
                Text("全局配置")
            } footer: {
                Text("快捷切换用于在当前屏幕与上一个活跃屏幕之间快速移动鼠标，支持录入双击 Command / Control / Option。开机自启动后仅常驻菜单栏，程序坞不显示图标。")
            }

            Section {
                if store.displays.isEmpty {
                    ContentUnavailableView(
                        "未检测到显示器",
                        systemImage: "display.trianglebadge.exclamationmark",
                        description: Text("请连接显示器以配置快捷键。")
                    )
                    .frame(minHeight: 120)
                } else {
                    ForEach(store.displays) { display in
                        DisplayRow(display: display)
                    }
                }
            } header: {
                Text("屏幕配置（当前识别 \(max(store.totalScreenCount, store.displays.count)) 块屏幕）")
            } footer: {
                Text("为每块屏幕录制独立快捷键，按下后鼠标跳转到对应屏幕。")
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("标记屏幕") {
                    store.relabelScreens()
                }
                .help("在每一块屏幕上显示其编号与快捷键")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshInputMonitoringState()
            store.refreshLaunchAtLoginState()
        }
    }

    private var permissionRow: some View {
        HStack {
            Label("输入监控权限", systemImage: "hand.raised")

            Spacer(minLength: 12)

            if store.inputMonitoringGranted {
                Label("已授权", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            } else {
                Button("前往授权…") {
                    store.requestInputMonitoringAccess()
                }
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Display Row
struct DisplayRow: View {
    let display: DisplayShortcut
    @EnvironmentObject private var store: MouseDanceStore
    @State private var isRecording = false

    var body: some View {
        HStack {
            Label {
                HStack(spacing: 6) {
                    Text(display.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("屏幕 \(display.number)")
                        .foregroundStyle(.secondary)
                    if display.isBuiltin {
                        Text("内建")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }
            } icon: {
                Image(systemName: display.isBuiltin ? "laptopcomputer" : "display")
            }

            Spacer(minLength: 12)

            ShortcutRecorderView(
                shortcut: store.binding(for: display.displayID),
                isRecording: $isRecording
            )
            .frame(width: 180, height: 24)
        }
    }
}
