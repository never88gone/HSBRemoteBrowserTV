//
//  ModernRemoteStatusTopBar.swift
//  HSBWatchCompanion
//

import SwiftUI

struct ModernRemoteStatusTopBar: View {
    @ObservedObject var coordinatorObserver: CoordinatorObservable
    @Binding var showingBrowserGuide: Bool
    @Binding var showingSystemGuide: Bool
    @State private var showingBrowserManageActionSheet: Bool = false
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    init(
        coordinatorObserver: CoordinatorObservable,
        showingBrowserGuide: Binding<Bool>,
        showingSystemGuide: Binding<Bool>
    ) {
        self.coordinatorObserver = coordinatorObserver
        self._showingBrowserGuide = showingBrowserGuide
        self._showingSystemGuide = showingSystemGuide
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // 左侧一体化返回按钮
            Button(action: {
                lightHaptic.impactOccurred()
                NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("返回")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 9)
                .background(
                    Capsule()
                        .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                )
                .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            if coordinatorObserver.isTargetMac {
                // Mac 原生系统直控专属状态条 (真实展示隔空播放投送连通性)
                HStack(spacing: 6) {
                    Circle()
                        .fill(coordinatorObserver.isNativeConnected ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(coordinatorObserver.isNativeConnected ? .green : .orange)
                    Text(coordinatorObserver.isNativeConnected ? "隔空播放已就绪: \(coordinatorObserver.targetDeviceName.isEmpty ? "Mac电脑" : coordinatorObserver.targetDeviceName)" : "未投送隔空播放 · 点击下方投送")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                )
            } else {
                // 1.1 大屏通道状态 (糖葫芦浏览器/专有控制/双指滚动/高级菜单)
                Button(action: {
                    lightHaptic.impactOccurred()
                    if coordinatorObserver.isHSBBrowserConnected {
                        showingBrowserManageActionSheet = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingBrowserGuide = true
                        }
                    }
                }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(browserStatusColor)
                            .frame(width: 6, height: 6)
                        Text(browserStatusText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(coordinatorObserver.isHSBBrowserConnected ? .primary : (coordinatorObserver.isHSBBrowserReconnecting ? .orange : .secondary))
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .actionSheet(isPresented: $showingBrowserManageActionSheet) {
                    ActionSheet(
                        title: Text("大屏通道控制 (\(coordinatorObserver.browserDeviceName.isEmpty ? "糖葫芦浏览器" : coordinatorObserver.browserDeviceName))"),
                        message: Text("当前已建立 TLS 1.2 加密长连接专线 (端口 56789)，支持触控板滑动、双指滚动与 EPG 协同。"),
                        buttons: [
                            .default(Text("🔄 刷新与测试大屏通道")) {
                                lightHaptic.impactOccurred()
                                coordinatorObserver.refreshBrowserChannel()
                            },
                            .default(Text("📱 重新扫码配对新大屏")) {
                                lightHaptic.impactOccurred()
                                coordinatorObserver.forgetPairedBrowserAndRescan()
                            },
                            .destructive(Text("🚫 断开大屏连接")) {
                                lightHaptic.impactOccurred()
                                coordinatorObserver.disconnectBrowserChannel()
                            },
                            .cancel(Text("取消"))
                        ]
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBShowScreenManageSheetNotification"))) { _ in
                    self.showingBrowserManageActionSheet = true
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBDismissScreenManageSheetNotification"))) { _ in
                    self.showingBrowserManageActionSheet = false
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBRefreshScreenChannelNotification"))) { _ in
                    self.showingBrowserManageActionSheet = false
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBDisconnectScreenChannelNotification"))) { _ in
                    self.showingBrowserManageActionSheet = false
                }
                
                // 1.2 Apple TV 系统原生通道状态 (Home/电源/全局控制)
                Button(action: {
                    lightHaptic.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingSystemGuide = true
                    }
                }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(systemStatusColor)
                            .frame(width: 6, height: 6)
                        Text(systemStatusText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(coordinatorObserver.isNativeConnected ? .primary : .secondary)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            // 右侧打字键盘入口
            Button(action: {
                lightHaptic.impactOccurred()
                NotificationCenter.default.post(name: Notification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
            }) {
                Image(systemName: "keyboard")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 9)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                    )
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
    
    // MARK: - Dual Channel Status Displays (大屏通道 & 系统原生通道)
    private var browserStatusColor: Color {
        if coordinatorObserver.isTargetMac {
            return .gray
        } else if coordinatorObserver.isHSBBrowserConnected {
            return .green
        } else if coordinatorObserver.isHSBBrowserReconnecting {
            return .orange
        } else if coordinatorObserver.nearbyDiscoveredBrowserTV != nil {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var browserStatusText: String {
        if coordinatorObserver.isTargetMac {
            return "大屏: 未连接"
        }
        if coordinatorObserver.isHSBBrowserConnected {
            let name = coordinatorObserver.browserDeviceName.isEmpty ? "已连接" : coordinatorObserver.browserDeviceName
            return "大屏: \(name)"
        } else if coordinatorObserver.isHSBBrowserReconnecting {
            return "大屏: 连接中..."
        } else if let nearby = coordinatorObserver.nearbyDiscoveredBrowserTV {
            return "大屏: 发现可连"
        } else {
            return "大屏: 未连接"
        }
    }
    
    private var systemStatusColor: Color {
        if coordinatorObserver.isTargetMac {
            return coordinatorObserver.isNativeConnected ? .green : .orange
        }
        if coordinatorObserver.isNativeConnected {
            return .green
        }
        if coordinatorObserver.isHSBBrowserConnected {
            return .green.opacity(0.8)
        }
        switch coordinatorObserver.state {
        case .ready: return .green
        case .connecting, .pairing: return .orange
        case .scanning: return .tanghuluBrandBlue
        case .failed: return .orange
        case .disconnected: return .gray
        }
    }
    
    private var systemStatusText: String {
        if coordinatorObserver.isTargetMac {
            let name = (!coordinatorObserver.targetDeviceName.isEmpty && coordinatorObserver.targetDeviceName != "Mac") ? coordinatorObserver.targetDeviceName : "Mac电脑"
            return coordinatorObserver.isNativeConnected ? "Mac隔空播放: \(name)" : "Mac: 未投送"
        }
        if coordinatorObserver.isNativeConnected {
            let name = (!coordinatorObserver.targetDeviceName.isEmpty && coordinatorObserver.targetDeviceName != "Mac") ? coordinatorObserver.targetDeviceName : "已连接"
            return "系统: \(name)"
        }
        if coordinatorObserver.isHSBBrowserConnected {
            return "系统: 协同就绪"
        }
        switch coordinatorObserver.state {
        case .ready(let name, _):
            return "系统: \(name)"
        case .connecting:
            return "系统: 连接中..."
        case .pairing:
            return "系统: 配对中..."
        case .scanning:
            return "系统: 扫描中..."
        case .failed(let err):
            if err.contains("待机") {
                return "系统: 待机唤醒"
            }
            return "系统: 未连接"
        case .disconnected:
            return "系统: 未连接"
        }
    }
}

#if DEBUG
private struct StatusTopBarPreviewHost: View {
    @StateObject private var observer = CoordinatorObservable(coordinator: DualModeRemoteCoordinator.shared)
    @State private var bGuide = false
    @State private var sGuide = false
    var body: some View {
        ZStack {
            DuoPalette.canvasBg.ignoresSafeArea()
            ModernRemoteStatusTopBar(
                coordinatorObserver: observer,
                showingBrowserGuide: $bGuide,
                showingSystemGuide: $sGuide
            )
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("双模状态导航顶栏") {
    StatusTopBarPreviewHost()
}
#endif
