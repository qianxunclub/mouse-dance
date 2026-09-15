import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject private var store: MouseDanceStore
    @EnvironmentObject private var updateManager: UpdateManager
    @Environment(\.openWindow) private var openWindow
    @State private var isRecordingToggle = false

    var body: some View {
        Form {
            Section {
                permissionRow

                VStack(alignment: .leading, spacing: 4) {
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

                    HStack(spacing: 3) {
                        Text("当前屏幕与上一个活跃屏幕之间切换，支持双击")
                        Image(systemName: "command")
                        Text(" 、")
                        Image(systemName: "control")
                        Text(" 、")
                        Image(systemName: "option")
                        Text("。")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("指针跟随激活 App", systemImage: "cursorarrow.motionlines")

                        Spacer(minLength: 12)

                        Toggle("指针跟随激活 App", isOn: $store.cursorFollowsAppSwitch)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .frame(height: 24)

                    Text("开启后，切换到另一块屏幕上的 App 时，指针会自动跳到该 App 的最前窗口；同一块屏幕内切换不受影响。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("开机自启动", systemImage: "power")

                        Spacer(minLength: 12)

                        Toggle("开机自启动", isOn: store.launchAtLoginBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .frame(height: 24)

                    Text("开启后登录系统即自动运行，仅显示菜单栏图标，程序坞不显示图标。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            } header: {
                Text("全局配置")
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

            Section {
                HStack {
                    Label("当前版本", systemImage: "tag")
                    Spacer(minLength: 12)
                    Text(updateManager.currentVersion)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 24)

                HStack {
                    Label("软件更新", systemImage: "arrow.triangle.2.circlepath")
                    Spacer(minLength: 12)

                    if case .available(let update) = updateManager.status {
                        Text("可更新到 \(update.version)")
                            .foregroundStyle(.tint)
                    }

                    Button("检查更新…") {
                        Task {
                            await updateManager.checkForUpdates()
                            openWindow(id: MouseDanceWindowIdentifier.update)
                        }
                    }
                    .controlSize(.small)
                }
                .frame(height: 24)
            } header: {
                Text("版本与更新")
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .toolbar {
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.relabelScreens()
                } label: {
                    Label("标记屏幕", systemImage: "rectangle.grid.3x2")
                }
                .labelStyle(.titleAndIcon)
                .help("在每一块屏幕上显示其编号与快捷键")
            }
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.12), in: .capsule)
            } else {
                Button("前往授权…") {
                    store.requestInputMonitoringAccess()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
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
