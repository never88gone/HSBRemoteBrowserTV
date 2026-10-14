//
//  MacOSMediaRemoteView.swift
//  HSBWatchCompanion
//
//  方案 A：macOS 原生媒体控制中心
//  通过 Apple 原生 MRP (MediaRemote) 协议通道免装软件直连 Mac，
//  专为 Mac 电脑定制的多媒体播放、音量与系统调度控制台。
//

import SwiftUI

public struct MacOSMediaRemoteView: View {
    public let deviceName: String
    public var onDismiss: (() -> Void)?
    
    @State private var isPlaying: Bool = true
    @State private var wavePhase: CGFloat = 0.0
    @State private var isMuted: Bool = false
    
    private let hawthornRed = Color(red: 224.0 / 255.0, green: 36.0 / 255.0, blue: 56.0 / 255.0)
    private let darkCarbon = Color(red: 34.0 / 255.0, green: 34.0 / 255.0, blue: 34.0 / 255.0)
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    public init(deviceName: String = "Mac", onDismiss: (() -> Void)? = nil) {
        self.deviceName = deviceName
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // 1. 顶部 Mac 专属终端识别徽章
            HStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(hawthornRed)
                
                Text(deviceName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("macOS 媒体终端")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer(minLength: 8)
            
            // 2. 动态黑胶唱片 / 音浪卡片 (Now Playing Visualizer)
            ZStack {
                // 外层磨砂发光底座
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                VStack(spacing: 16) {
                    // 黑胶同心圆唱片动画
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 130, height: 130)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .frame(width: 70, height: 70)
                        
                        // 唱片中心糖葫芦朱砂红轴心
                        Circle()
                            .fill(hawthornRed)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: hawthornRed.opacity(0.5), radius: 8, x: 0, y: 0)
                    }
                    
                    // 动态律动音浪条 (Audio Wave Visualizer)
                    HStack(spacing: 5) {
                        ForEach(0..<12) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(hawthornRed.opacity(0.85))
                                .frame(width: 4, height: waveBarHeight(index: i))
                        }
                    }
                    .frame(height: 24)
                    
                    // 状态说明文字
                    VStack(spacing: 4) {
                        Text(isPlaying ? "正在控制 Mac 系统媒体播放" : "Mac 媒体已暂停")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("支持 Apple Music、播客、视频与系统全局媒体")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.vertical, 24)
            }
            .frame(height: 250)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 8)
            
            // 3. 核心媒体控制按钮群 (上一首、播放/暂停、下一首)
            HStack(spacing: 36) {
                // 上一首
                Button(action: {
                    haptic.impactOccurred()
                    DualModeRemoteCoordinator.shared.sendDPad(direction: .left, action: .tap)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 58, height: 58)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                // 大号朱砂红播放/暂停主按键
                Button(action: {
                    haptic.impactOccurred()
                    isPlaying.toggle()
                    DualModeRemoteCoordinator.shared.sendSystemKey(.playPause)
                }) {
                    ZStack {
                        Circle()
                            .fill(hawthornRed)
                            .frame(width: 76, height: 76)
                            .shadow(color: hawthornRed.opacity(0.4), radius: 12, x: 0, y: 4)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                // 下一首
                Button(action: {
                    haptic.impactOccurred()
                    DualModeRemoteCoordinator.shared.sendDPad(direction: .right, action: .tap)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 58, height: 58)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.vertical, 8)
            
            // 4. 音量与系统功能岛 (Volume & System Island)
            HStack(spacing: 12) {
                // 音量减
                Button(action: {
                    lightHaptic.impactOccurred()
                    DualModeRemoteCoordinator.shared.sendSystemKey(.volumeDown)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.minus.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("音量 -")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                // 一键静音
                Button(action: {
                    lightHaptic.impactOccurred()
                    isMuted.toggle()
                    DualModeRemoteCoordinator.shared.sendSystemKey(.mute)
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isMuted ? hawthornRed : .white.opacity(0.85))
                        .frame(width: 46, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                
                // 音量加
                Button(action: {
                    lightHaptic.impactOccurred()
                    DualModeRemoteCoordinator.shared.sendSystemKey(.volumeUp)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.plus.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("音量 +")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                // 屏幕休眠 / 唤醒
                Button(action: {
                    lightHaptic.impactOccurred()
                    DualModeRemoteCoordinator.shared.sendSystemKey(.power)
                }) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 46, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            
            // 5. 底部协议保障指引卡片
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color.green)
                Text("已通过 Apple 原生 Companion 媒体通道安全直连，无需在 Mac 安装任何软件")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(darkCarbon.ignoresSafeArea())
        .onAppear {
            startWaveAnimation()
        }
    }
    
    private func startWaveAnimation() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            wavePhase = 1.0
        }
    }
    
    private func waveBarHeight(index: Int) -> CGFloat {
        if !isPlaying { return 4.0 }
        let pattern: [CGFloat] = [6, 14, 22, 10, 18, 24, 12, 20, 8, 16, 22, 10]
        let base = pattern[index % pattern.count]
        let factor = (CGFloat(index % 3) * 0.2 + 0.8)
        return wavePhase > 0.5 ? base * factor : max(4, base * 0.5)
    }
}

// MARK: - 按压弹性微动效果
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
