//
//  ModernRemoteContainerView.swift
//  HSBWatchCompanion
//

import SwiftUI
import Network

public struct ModernRemoteContainerView: View {
    @ObservedObject private var coordinatorObserver = CoordinatorObservable(coordinator: DualModeRemoteCoordinator.shared)
    @State private var selectedControlTab: Int = {
        if UserDefaults.standard.object(forKey: "UITestRemoteTab") != nil {
            return UserDefaults.standard.integer(forKey: "UITestRemoteTab")
        }
        if UserDefaults.standard.bool(forKey: "UITestShowDPad") {
            return 0
        }
        return 0 // 默认首选系统遥控
    }()
    @State private var isKeyboardPresented: Bool = UserDefaults.standard.bool(forKey: "UITestShowKeyboard")
    
    private let textInputManager = RemoteTextInputManager()
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    private var isBrowserRemoteVisible: Bool {
        coordinatorObserver.isHSBBrowserConnected || UserDefaults.standard.bool(forKey: "UITestForceShowBrowserTab")
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 糖葫芦深空极光天蓝渐变背景
            Color.auroraBackgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 1. 顶部紧凑流线型状态栏 (居中平衡排布)
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text(statusText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                    )
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                // 2. 遥控场景 Tab 切换栏 (未连接 hsbtvbrowser 真实大屏时仅展示系统、IPTV、演讲)
                Picker("遥控场景", selection: $selectedControlTab) {
                    Text("系统").tag(0)
                    if isBrowserRemoteVisible {
                        Text("触控").tag(1)
                    }
                    Text("IPTV").tag(2)
                    Text("演讲").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .onChange(of: isBrowserRemoteVisible) { visible in
                    if !visible && selectedControlTab == 1 {
                        selectedControlTab = 0
                    }
                }
                .onAppear {
                    if !isBrowserRemoteVisible && selectedControlTab == 1 {
                        selectedControlTab = 0
                    }
                }
                
                // 3. 核心场景交互面板
                ZStack {
                    if selectedControlTab == 0 {
                        // Tab 1: 系统遥控 (Apple TV 原生 D-pad 轮盘与一体化控制岛)
                        systemRemoteView
                    } else if selectedControlTab == 1 && isBrowserRemoteVisible {
                        // Tab 2: 扩展触控板 (仅在连接真实 hsbtvbrowser 时呈现)
                        webRemoteView
                    } else if selectedControlTab == 2 {
                        // Tab 3: IPTV 遥控 (经典 CH+/- 换台、音量塔、频道快捷直达与数字选台)
                        ModernIPTVControlView(
                            onAction: { action in
                                HSBTVOSConnectionManager.shared().sendSimulateAction(action)
                            },
                            onPlayChannel: { name, channelId in
                                HSBTVOSConnectionManager.shared().sendPayload([
                                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvPlayChannel.rawValue,
                                    HSBRemotePayloadKeyChannel: name,
                                    HSBRemotePayloadKeyId: channelId
                                ])
                            },
                            onDigit: { digit in
                                HSBTVOSConnectionManager.shared().sendSimulateAction(
                                    .digit,
                                    withParams: [HSBRemotePayloadKeyDigit: digit]
                                )
                            }
                        )
                    } else {
                        // Tab 4: PDF 遥控 (商务演讲翻页大板、首尾页跳转、激光笔与屏幕涂鸦)
                        ModernPDFControlView(
                            onPageChange: { isNext in
                                HSBTVOSConnectionManager.shared().sendSimulateAction(
                                    isNext ? .right : .left
                                )
                            },
                            onJumpPage: { isFirst in
                                HSBTVOSConnectionManager.shared().sendSimulateAction(
                                    isFirst ? .pageHome : .stop
                                )
                            },
                            onDrawAction: { type, point, color, width in
                                HSBTVOSConnectionManager.shared().sendPayload([
                                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw.rawValue,
                                    HSBRemotePayloadKeyType: type,
                                    HSBRemotePayloadKeyX: Double(point.x),
                                    HSBRemotePayloadKeyY: Double(point.y),
                                    HSBRemotePayloadKeyColor: color,
                                    HSBRemotePayloadKeyWidth: Double(width)
                                ])
                            },
                            onClear: {
                                HSBTVOSConnectionManager.shared().sendPayload([
                                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw.rawValue,
                                    HSBRemotePayloadKeyType: HSBRemoteDrawTypeClear
                                ])
                            },
                            onUndo: {
                                HSBTVOSConnectionManager.shared().sendPayload([
                                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw.rawValue,
                                    HSBRemotePayloadKeyType: HSBRemoteDrawTypeUndo
                                ])
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // 键盘输入抽屉
            if isKeyboardPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isKeyboardPresented = false
                    }
                
                VStack {
                    Spacer()
                    ModernKeyboardInputView(
                        isPresented: $isKeyboardPresented,
                        onTextChange: { text, isMarked in
                            textInputManager.handleTextChanged(newText: text, hasMarkedText: isMarked)
                        },
                        onSubmit: {
                            DualModeRemoteCoordinator.shared.sendKeyCommand(key: .enter)
                            isKeyboardPresented = false
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isKeyboardPresented)
        .accentColor(.tanghuluBrandBlue)
        .onAppear {
            setupTextInputManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBToggleRemoteKeyboardNotification"))) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                lightHaptic.impactOccurred()
                isKeyboardPresented.toggle()
            }
        }
    }
    
    // MARK: - Tab 1: 系统遥控视图 (黄金比例与一体化控制岛)
    private var systemRemoteView: some View {
        VStack(spacing: 0) {
            // 上半部微缓冲 (收紧顶部间隙，让轮盘自然承接Tab栏)
            Spacer(minLength: 6)
                .frame(maxHeight: 14)
            
            // 现代 270pt 质感 D-pad 轮盘 (居于单手握持最佳操控中轴)
            ModernDPadView(
                size: 270,
                onDirection: { dir, action in
                    DualModeRemoteCoordinator.shared.sendDPad(direction: dir, action: action)
                },
                onSelect: { action in
                    DualModeRemoteCoordinator.shared.sendSelect(action: action)
                }
            )
            
            // 轮盘与控制岛之间的黄金呼吸间隙
            Spacer(minLength: 16)
                .frame(maxHeight: 32)
            
            // 下半屏：高质感一体化控制岛 (Control Island)
            VStack(spacing: 16) {
                // 1. 媒体播放核心控制行 (快退 10 秒 / 播放暂停 / 快进 10 秒)
                HStack(spacing: 12) {
                    mediaControlButton(icon: "gobackward.10", title: "快退 10s") {
                        DualModeRemoteCoordinator.shared.sendDPad(direction: .left, action: .tap)
                    }
                    
                    mediaControlButton(icon: "playpause.fill", title: "播放 / 暂停", isPrimary: true) {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.playPause)
                    }
                    
                    mediaControlButton(icon: "goforward.10", title: "快进 10s") {
                        DualModeRemoteCoordinator.shared.sendDPad(direction: .right, action: .tap)
                    }
                }
                
                // 2. 系统核心功能行 (桌面, 返回, 静音, 待机)
                HStack(spacing: 16) {
                    systemIslandRoundButton(icon: "house.fill", label: "桌面") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.home)
                    }
                    systemIslandRoundButton(icon: "arrow.uturn.backward", label: "返回") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.menu)
                    }
                    systemIslandRoundButton(icon: "speaker.slash.fill", label: "静音") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.mute)
                    }
                    systemIslandRoundButton(icon: "power", label: "待机") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.power)
                    }
                }
                
                // 3. 硬件音量调节行
                HStack(spacing: 12) {
                    Button {
                        lightHaptic.impactOccurred()
                        DualModeRemoteCoordinator.shared.sendSystemKey(.volumeDown)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.minus.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("音量 -")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        lightHaptic.impactOccurred()
                        DualModeRemoteCoordinator.shared.sendSystemKey(.volumeUp)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.plus.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("音量 +")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            
            // 底部自然贴合安全区
            Spacer(minLength: 12)
        }
    }
    
    private func mediaControlButton(icon: String, title: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            lightHaptic.impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 16 : 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: isPrimary ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isPrimary ? Color.accentColor.opacity(0.2) : Color(UIColor.tertiarySystemBackground))
            .foregroundColor(isPrimary ? Color.accentColor : .primary)
            .cornerRadius(11)
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isPrimary ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private func systemIslandRoundButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Tab 2: 网页遥控视图
    private var webRemoteView: some View {
        VStack(spacing: 14) {
            // 触控微操板
            ModernTouchpadView(
                onPan: { dx, dy in
                    DualModeRemoteCoordinator.shared.sendCursorPan(dx: dx, dy: dy)
                },
                onTap: { mode, pt in
                    DualModeRemoteCoordinator.shared.sendTap(mode: mode, point: pt)
                },
                onScroll: { dx, dy in
                    DualModeRemoteCoordinator.shared.sendScroll(dx: dx, dy: dy)
                },
                onDrag: { state, dx, dy in
                    DualModeRemoteCoordinator.shared.sendDrag(state: state, dx: dx, dy: dy)
                },
                onZoom: { scale in
                    DualModeRemoteCoordinator.shared.sendZoom(scale: scale)
                }
            )
            .padding(.horizontal, 16)
            
            // 网页悬浮磨砂操作岛 (后退、前进、刷新、主页、放大)
            HStack(spacing: 8) {
                webNavButton(icon: "chevron.backward", title: "后退") {
                    DualModeRemoteCoordinator.shared.sendPageAction(.back)
                }
                webNavButton(icon: "chevron.forward", title: "前进") {
                    DualModeRemoteCoordinator.shared.sendPageAction(.forward)
                }
                webNavButton(icon: "arrow.clockwise", title: "刷新") {
                    DualModeRemoteCoordinator.shared.sendPageAction(.reload)
                }
                webNavButton(icon: "house", title: "主页") {
                    DualModeRemoteCoordinator.shared.sendPageAction(.home)
                }
                webNavButton(icon: "plus.magnifyingglass", title: "放大") {
                    DualModeRemoteCoordinator.shared.sendZoom(scale: 1.25)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    @ViewBuilder
    private func systemRoundButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func webNavButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(UIColor.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func setupTextInputManager() {
        textInputManager.delegate = coordinatorObserver
    }
    
    private var statusColor: Color {
        switch coordinatorObserver.state {
        case .ready: return .tanghuluBrandBlue
        case .connecting, .pairing: return .orange
        case .scanning: return .tanghuluBrandBlue
        case .failed: return .red
        case .disconnected: return .gray
        }
    }
    
    private var statusText: String {
        switch coordinatorObserver.state {
        case .ready(let name, _):
            return "\(name) (已连接)"
        case .connecting(let name, _):
            return "正在连接 \(name)..."
        case .pairing(let name, _):
            return "正在配对 \(name)..."
        case .scanning:
            return "正在扫描局域网..."
        case .failed:
            return "连接异常"
        case .disconnected:
            return "未连接"
        }
    }
}

// MARK: - Observer Class for Coordinator State
private final class CoordinatorObservable: ObservableObject, DualModeRemoteCoordinatorDelegate, RemoteTextInputManagerDelegate {
    @Published var state: HSBConnectionState = .disconnected
    @Published var isHSBBrowserConnected: Bool = false
    private let coordinator: DualModeRemoteCoordinator
    
    init(coordinator: DualModeRemoteCoordinator) {
        self.coordinator = coordinator
        self.state = coordinator.currentState
        self.isHSBBrowserConnected = HSBTVOSConnectionManager.shared().isConnected
        coordinator.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTVOSConnectionNotification(_:)),
            name: .HSBTVOSConnectionState,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleTVOSConnectionNotification(_ note: Notification) {
        DispatchQueue.main.async {
            self.isHSBBrowserConnected = HSBTVOSConnectionManager.shared().isConnected
        }
    }
    
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didChangeState state: HSBConnectionState) {
        DispatchQueue.main.async {
            self.state = state
            self.isHSBBrowserConnected = HSBTVOSConnectionManager.shared().isConnected
        }
    }
    
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didReceiveScreenMessage message: [String: Any]) {
        // 接收消息处理
    }
    
    func textInputManager(_ manager: RemoteTextInputManager, didProduceRTIPayload data: Data) {
        // Native RTI 同步
    }
    
    func textInputManager(_ manager: RemoteTextInputManager, didFallbackToScript script: String) {
        coordinator.executeJavaScript(script, completion: nil)
    }
}

extension Color {
    public static let tanghuluBrandBlue = Color(red: 28.0 / 255.0, green: 123.0 / 255.0, blue: 249.0 / 255.0)
    public static let auroraBackgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 10.0 / 255.0, green: 28.0 / 255.0, blue: 56.0 / 255.0),
            Color(red: 6.0 / 255.0, green: 15.0 / 255.0, blue: 34.0 / 255.0),
            Color(red: 2.0 / 255.0, green: 5.0 / 255.0, blue: 14.0 / 255.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
