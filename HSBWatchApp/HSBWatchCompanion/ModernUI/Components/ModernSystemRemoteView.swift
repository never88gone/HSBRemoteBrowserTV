//
//  ModernSystemRemoteView.swift
//  HSBWatchCompanion
//

import SwiftUI

public struct ModernSystemRemoteView: View {
    public var dpadSize: CGFloat = 220.0
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    @State private var isAwakeAndConnected: Bool = DualModeRemoteCoordinator.shared.nativeClient.isConnected && !DualModeRemoteCoordinator.shared.isSleeping
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public init(dpadSize: CGFloat = 220.0) {
        self.dpadSize = dpadSize
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 上半部微缓冲 (收紧顶部间隙，让轮盘自然承接Tab栏)
            Spacer(minLength: 4)
                .frame(maxHeight: 12)
            
            // 现代 220pt 质感 D-pad 轮盘 (居于单手握持最佳操控中轴，舒适人体工学)
            ModernDPadView(
                size: dpadSize,
                onDirection: { dir, action in
                    DualModeRemoteCoordinator.shared.sendDPad(direction: dir, action: action)
                },
                onSelect: { action in
                    DualModeRemoteCoordinator.shared.sendSelect(action: action)
                }
            )
            
            // 轮盘与控制岛之间的黄金呼吸间隙
            Spacer(minLength: 8)
                .frame(maxHeight: 24)
            
            // 下半屏：高质感一体化控制岛 (Control Island)
            VStack(spacing: 10) {
                // 1. 媒体播放核心控制行 (快退 10 秒 / 播放暂停 / 快进 10 秒)
                HStack(spacing: 10) {
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
                HStack(spacing: 12) {
                    systemIslandRoundButton(icon: "house.fill", label: "桌面") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.home)
                    }
                    systemIslandRoundButton(icon: "arrow.uturn.backward", label: "返回") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.menu)
                    }
                    systemIslandRoundButton(icon: "speaker.slash.fill", label: "静音") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.mute)
                    }
                    systemIslandRoundButton(
                        icon: "power",
                        label: isAwakeAndConnected ? "待机" : "开机",
                        tintColor: isAwakeAndConnected ? nil : Color.green
                    ) {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.power)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.isAwakeAndConnected = DualModeRemoteCoordinator.shared.nativeClient.isConnected && !DualModeRemoteCoordinator.shared.isSleeping
                        }
                    }
                }
                
                // 3. 硬件音量调节行
                HStack(spacing: 10) {
                    Button {
                        lightHaptic.impactOccurred()
                        DualModeRemoteCoordinator.shared.sendSystemKey(.volumeDown)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.minus.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("音量 -")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                    .accessibilityIdentifier("volume_down_button")
                    .accessibilityLabel("音量 -")
                    
                    Button {
                        lightHaptic.impactOccurred()
                        DualModeRemoteCoordinator.shared.sendSystemKey(.volumeUp)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.plus.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("音量 +")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                    .accessibilityIdentifier("volume_up_button")
                    .accessibilityLabel("音量 +")
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            
            // 底部自然贴合安全区
            Spacer(minLength: 6)
                .frame(maxHeight: 16)
        }
        .onReceive(timer) { _ in
            let current = DualModeRemoteCoordinator.shared.nativeClient.isConnected && !DualModeRemoteCoordinator.shared.isSleeping
            if current != self.isAwakeAndConnected {
                self.isAwakeAndConnected = current
            }
        }
    }
    
    private func mediaControlButton(icon: String, title: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            lightHaptic.impactOccurred()
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 14 : 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: isPrimary ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(isPrimary ? Color.accentColor.opacity(0.2) : Color(UIColor.tertiarySystemBackground))
            .foregroundColor(isPrimary ? Color.accentColor : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPrimary ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("media_\(title)")
        .accessibilityLabel(title)
    }
    
    @ViewBuilder
    private func systemIslandRoundButton(icon: String, label: String, tintColor: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(tintColor != nil ? tintColor!.opacity(0.18) : Color(UIColor.tertiarySystemBackground))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(tintColor != nil ? tintColor!.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(tintColor ?? .primary)
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(tintColor ?? .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("system_\(label)")
        .accessibilityLabel(label)
    }
}
