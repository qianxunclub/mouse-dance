import AppKit
import Combine
import SwiftUI

// MARK: - 面板状态

@MainActor
final class SwitcherPanelState: ObservableObject {
    @Published var windows: [SwitcherWindow] = []
    @Published var selectedIndex: Int = 0
    @Published var appIcons: [pid_t: NSImage] = [:]

    /// 鼠标点击某个窗口：直接选中并确认
    var onSelect: ((Int) -> Void)?
}

// MARK: - 尺寸

/// 图标与选中框按比例放大，图标 72pt、选中框 88pt；
/// 单格宽度与面板高度同步增加，避免图标变大后拥挤。
/// 想再调大小只需改这一组常量，视图与窗口 frame 都从这里取值。
private nonisolated enum PanelMetrics {
    static let iconSize: CGFloat = 72
    static let highlightSize: CGFloat = 88
    static let highlightRadius: CGFloat = 20
    static let tileWidth: CGFloat = 104
    static let tileSpacing: CGFloat = 8
    static let tilePitch: CGFloat = tileWidth + tileSpacing      // 112
    static let titleSpacing: CGFloat = 8
    static let panelPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 24
    static let panelHeight: CGFloat = 164
    static let emptyWidth: CGFloat = 300
    static let emptyHeight: CGFloat = 104
    /// 面板左右内边距 + ScrollView 内部 2pt 边距（两侧）
    static let horizontalChrome: CGFloat = panelPadding * 2 + 4   // 36
}

// MARK: - 面板视图

/// 贴近系统 ⌘Tab 的横向图标条：没有标题栏、计数与操作提示，
/// 只有一排窗口图标 + 选中高亮 + 每个窗口的一行标题（用于区分同一 App 的多个窗口）。
private struct SwitcherPanelView: View {
    @ObservedObject var state: SwitcherPanelState

    var body: some View {
        Group {
            if state.windows.isEmpty {
                Text("没有可切换的窗口")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(
                        width: PanelMetrics.emptyWidth - PanelMetrics.panelPadding * 2,
                        height: PanelMetrics.emptyHeight - PanelMetrics.panelPadding * 2
                    )
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PanelMetrics.tileSpacing) {
                            ForEach(state.windows.indices, id: \.self) { index in
                                let window = state.windows[index]
                                SwitcherWindowTile(
                                    window: window,
                                    icon: state.appIcons[window.ownerPID],
                                    isSelected: index == state.selectedIndex
                                )
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture { state.onSelect?(index) }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .onChange(of: state.selectedIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(PanelMetrics.panelPadding)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct SwitcherWindowTile: View {
    let window: SwitcherWindow
    let icon: NSImage?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: PanelMetrics.titleSpacing) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: PanelMetrics.highlightRadius, style: .continuous)
                        .fill(Color.accentColor.opacity(0.22))
                }
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: PanelMetrics.iconSize, height: PanelMetrics.iconSize)
                } else {
                    Image(systemName: "macwindow")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: PanelMetrics.highlightSize, height: PanelMetrics.highlightSize)
            .overlay(
                RoundedRectangle(cornerRadius: PanelMetrics.highlightRadius, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
            )

            Text(window.title)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: PanelMetrics.tileWidth)
        .padding(.vertical, 4)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

// MARK: - 面板宿主

@MainActor
final class SwitcherPanelController {
    private var panel: NSPanel?
    private let state = SwitcherPanelState()
    private var onCancel: (() -> Void)?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    init() {
        // 面板是 nonactivatingPanel：点击其他应用时不会产生本应用的鼠标事件，
        // 所以同时监听本地与全局鼠标按下事件，才能覆盖面板外的任意位置。
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseDown()
            }
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseDown()
            }
        }
    }

    deinit {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
    }

    func show(
        windows: [SwitcherWindow],
        selectedIndex: Int,
        appIcons: [pid_t: NSImage],
        onSelect: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        state.windows = windows
        state.selectedIndex = selectedIndex
        state.appIcons = appIcons
        state.onSelect = onSelect
        self.onCancel = onCancel

        let width = windows.isEmpty
            ? PanelMetrics.emptyWidth
            : CGFloat(windows.count) * PanelMetrics.tilePitch + PanelMetrics.horizontalChrome
        let height = windows.isEmpty ? PanelMetrics.emptyHeight : PanelMetrics.panelHeight
        let frame = centeredFrame(width: width, height: height)

        if panel == nil {
            panel = makePanel(frame: frame)
        }
        guard let panel else { return }

        panel.setFrame(frame, display: true)
        // 新会话从透明开始，避免切换框突然出现。
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func setSelectedIndex(_ index: Int) {
        state.selectedIndex = index
    }

    func hide() {
        guard let panel else {
            state.onSelect = nil
            onCancel = nil
            return
        }

        state.onSelect = nil
        onCancel = nil
        // 立即释放 controller 对旧面板的占用，新的会话可以在淡出期间创建新面板。
        self.panel = nil

        // 先淡出，再移出窗口层级；切换状态由 Controller 立即结束，
        // 因此动画不会延迟窗口聚焦或阻塞下一次快捷键会话。
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1
        })
    }

    private func handleMouseDown() {
        guard panel != nil, let onCancel else { return }
        let location = NSEvent.mouseLocation
        guard !panel!.frame.contains(location) else { return }
        onCancel()
    }

    private func centeredFrame(width: CGFloat, height: CGFloat) -> CGRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: width, height: height)
        // 窗口多时限制在屏幕宽度的 90% 以内，超出部分由图标条横向滚动
        let finalWidth = min(width, visible.width * 0.9)
        return CGRect(
            x: visible.midX - finalWidth / 2,
            y: visible.midY - height / 2,
            width: finalWidth,
            height: height
        )
    }

    private func makePanel(frame: CGRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // 高于全屏应用所在层级，保证在全屏 Space 里也能覆盖
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.ignoresMouseEvents = false
        panel.contentView = NSHostingView(rootView: SwitcherPanelView(state: state))
        return panel
    }
}
