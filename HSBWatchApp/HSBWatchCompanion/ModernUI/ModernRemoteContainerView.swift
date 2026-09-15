//
//  ModernRemoteContainerView.swift
//  HSBWatchCompanion
//

import SwiftUI
import Network

public struct ModernRemoteContainerView: View {
    @ObservedObject private var coordinatorObserver = CoordinatorObservable(coordinator: DualModeRemoteCoordinator.shared)
    @State private var selectedControlTab: Int = UserDefaults.standard.bool(forKey: "UITestShowDPad") ? 1 : 0
    @State private var isKeyboardPresented: Bool = UserDefaults.standard.bool(forKey: "UITestShowKeyboard")
    
    private let textInputManager = RemoteTextInputManager()
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 背景渐变
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // 顶部状态栏
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    
                    Spacer()
                    
                    // 触控板与按键切换器
                    Picker("控制形态", selection: $selectedControlTab) {
                        Text("触控微操").tag(0)
                        Text("按键轮盘").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 170)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // 核心交互区
                ZStack {
                    if selectedControlTab == 0 {
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
                    } else {
                        // 现代圆形 D-pad 轮盘
                        VStack {
                            Spacer()
                            ModernDPadView(
                                onDirection: { dir, action in
                                    DualModeRemoteCoordinator.shared.sendDPad(direction: dir, action: action)
                                },
                                onSelect: { action in
                                    DualModeRemoteCoordinator.shared.sendSelect(action: action)
                                }
                            )
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 快捷工具栏
                ModernActionToolbar(
                    currentMode: Binding(
                        get: { DualModeRemoteCoordinator.shared.currentMode },
                        set: { DualModeRemoteCoordinator.shared.currentMode = $0 }
                    ),
                    onSystemKey: { key in
                        DualModeRemoteCoordinator.shared.sendSystemKey(key)
                    },
                    onPageAction: { action in
                        DualModeRemoteCoordinator.shared.sendPageAction(action)
                    },
                    onToggleKeyboard: {
                        isKeyboardPresented.toggle()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
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
        .onAppear {
            setupTextInputManager()
        }
    }
    
    private func setupTextInputManager() {
        textInputManager.delegate = coordinatorObserver
    }
    
    private var statusColor: Color {
        switch coordinatorObserver.state {
        case .ready: return .green
        case .connecting, .pairing: return .orange
        case .scanning: return .blue
        case .failed: return .red
        case .disconnected: return .gray
        }
    }
    
    private var statusText: String {
        switch coordinatorObserver.state {
        case .ready(let name, let mode):
            return "\(name) (\(mode.identifier))"
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
    private let coordinator: DualModeRemoteCoordinator
    
    init(coordinator: DualModeRemoteCoordinator) {
        self.coordinator = coordinator
        self.state = coordinator.currentState
        coordinator.delegate = self
    }
    
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didChangeState state: HSBConnectionState) {
        DispatchQueue.main.async {
            self.state = state
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
