import AppKit
import SwiftUI

// MARK: - Atmospheric Background
struct AtmosphericBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            
            // Abstract gradient blobs
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 90)
                .offset(x: animate ? -150 : 150, y: animate ? -80 : 80)
            
            Circle()
                .fill(Color.purple.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: animate ? 200 : -100, y: animate ? 150 : -150)
                
            Circle()
                .fill(Color.cyan.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: 0, y: animate ? 200 : -100)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - Permission Pill
struct PermissionPill: View {
    let granted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(granted ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                    .shadow(color: granted ? Color.green.opacity(0.5) : Color.orange.opacity(0.5), radius: 3)
                
                Text(granted ? "已获输入监控权限" : "需授权输入监控")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(granted ? .secondary : .primary)
                
                if !granted {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject private var store: MouseDanceStore
    @State private var isRecordingToggle = false
    
    private var displayColumns: [GridItem] {
        let count = store.displays.count > 1 ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: count)
    }

    var body: some View {
        ZStack {
            AtmosphericBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerSection
                    globalSettingsSection
                    screensSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshInputMonitoringState()
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow.motionlines")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 6)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("MouseDance")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("为每块屏幕独立配置快捷键")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Text("当前识别 \(max(store.totalScreenCount, store.displays.count)) 块屏幕")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer(minLength: 16)
            
            PermissionPill(granted: store.inputMonitoringGranted) {
                if !store.inputMonitoringGranted {
                    store.requestInputMonitoringAccess()
                } else {
                    store.recheckInputMonitoringAccess()
                }
            }
        }
    }
    
    private var globalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("全局配置")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("快捷切换")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("在当前屏幕与上一个活跃屏幕之间快速切换鼠标")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                ShortcutRecorderView(
                    shortcut: $store.toggleShortcut,
                    isRecording: $isRecordingToggle
                )
                .frame(width: 124, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isRecordingToggle ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isRecordingToggle ? 2 : 1)
                )
            }
            .padding(16)
            .background(panelBackground)
        }
    }
    
    private var screensSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("屏幕配置")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("双屏布局会自动并排展示，减少空白区域")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Button(action: { store.relabelScreens() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 10, weight: .bold))
                        Text("标记屏幕")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05), in: Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            
            Group {
                if store.displays.isEmpty {
                    EmptyStateView()
                        .frame(height: 120)
                } else {
                    LazyVGrid(columns: displayColumns, alignment: .leading, spacing: 12) {
                        ForEach(store.displays) { display in
                            DisplayCard(display: display)
                        }
                    }
                }
            }
            .padding(16)
            .background(panelBackground)
        }
    }
    
    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            
            Text("未检测到显示器")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            
            Text("请连接显示器以配置快捷键。")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Display Card
struct DisplayCard: View {
    let display: DisplayShortcut
    @EnvironmentObject private var store: MouseDanceStore
    @State private var isRecording = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Image(systemName: display.isBuiltin ? "laptopcomputer" : "display")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(display.isBuiltin ? .purple : .blue)
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(display.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("屏幕 \(display.number)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        if display.isBuiltin {
                            Text("内建")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15), in: Capsule())
                        }
                    }
                }
                .padding(.leading, 4)
                
                Spacer(minLength: 0)
            }
            
            Divider()
                .opacity(0.5)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("跳转快捷键")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                ShortcutRecorderView(
                    shortcut: store.binding(for: display.displayID),
                    isRecording: $isRecording
                )
                .frame(height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isRecording ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isRecording ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 12 : 8, y: isHovered ? 6 : 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
