//
//  ModernSystemRemoteView.swift
//  HSBWatchCompanion
//

import SwiftUI

public struct ModernSystemRemoteView: View {
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    public init() {}
    
    public var body: some View {
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
}
