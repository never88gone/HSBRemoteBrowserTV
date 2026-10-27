//
//  MacOSMediaRemoteView.swift
//  HSBWatchCompanion
//
//  方案 1：macOS 原生媒体控制中心 (100% 免装软件、系统隔空播放直连)
//  支持多媒体播放/暂停、快进/快退、曲目切换、系统硬件音量调节与静音控制。
//  彻底移除所有第三方守护程序、49888 端口与虚拟光标/触控板逻辑。
//

import SwiftUI

public struct MacOSMediaRemoteView: View {
    public let deviceName: String
    public var onDismiss: (() -> Void)?
    
    // 媒体播放与状态
    @State private var isPlaying: Bool = MacMediaCommandDispatcher.isPlaying
    @State private var wavePhase: CGFloat = 0.0
    @State private var isMuted: Bool = MacMediaCommandDispatcher.isMuted
    @State private var volume: Double = MacMediaCommandDispatcher.currentVolume
    @State private var isAirPlayConnected: Bool = true
    @State private var showHelpAlert: Bool = false
    
    private let hawthornRed = Color(red: 224.0 / 255.0, green: 36.0 / 255.0, blue: 56.0 / 255.0)
    private let darkCarbon = Color(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0)
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    public init(deviceName: String = "Mac", onDismiss: (() -> Void)? = nil) {
        self.deviceName = deviceName
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // 1. 顶部 Mac 终端识别与原生隔空播放状态条
            HStack(spacing: 8) {
                Button(action: {
                    haptic.impactOccurred()
                    DualModeRemoteCoordinator.shared.disconnectAll()
                    onDismiss?()
                    NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("断开")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                HStack(spacing: 6) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(hawthornRed)
                    Text(deviceName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                Button(action: {
                    if !isAirPlayConnected {
                        haptic.impactOccurred()
                        showHelpAlert = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isAirPlayConnected ? Color.green : Color.orange)
                            .frame(width: 6.5, height: 6.5)
                        Text(isAirPlayConnected ? "隔空播放已就绪" : "未开启隔空播放")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(isAirPlayConnected ? .white.opacity(0.85) : .orange)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isAirPlayConnected ? Color.white.opacity(0.08) : Color.orange.opacity(0.16))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Spacer(minLength: 10)
            
            // 2. 核心媒体音乐声波与律动视觉卡片
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            gradient: Gradient(colors: [hawthornRed.opacity(0.25), Color.black.opacity(0.4)]),
                            center: .center,
                            startRadius: 10,
                            endRadius: 90
                        ))
                        .frame(width: 170, height: 170)
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1.5))
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundColor(isPlaying ? hawthornRed : .white.opacity(0.35))
                        .scaleEffect(isPlaying ? 1.08 : 0.95)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPlaying)
                }
                
                // 律动频谱波形条
                HStack(spacing: 4) {
                    ForEach(0..<12) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isPlaying ? hawthornRed.opacity(0.85) : Color.white.opacity(0.2))
                            .frame(width: 3.5, height: waveBarHeight(index: i))
                            .animation(.easeInOut(duration: 0.25), value: wavePhase)
                    }
                }
                .frame(height: 26)
                
                Text(isPlaying ? "正在播放媒体 · macOS 系统原生音频直推" : "macOS 原生隔空播放媒体控制")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .padding(.horizontal, 16)
            
            Spacer(minLength: 10)
            
            // 3. 核心播放控制排组 (快退10s / 上一首 / 播放暂停 / 下一首 / 快进10s)
            HStack(spacing: 16) {
                Button(action: {
                    lightHaptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("backward")
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("previous")
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                // 核心大尺寸播放/暂停按键
                Button(action: {
                    haptic.impactOccurred()
                    isPlaying.toggle()
                    MacMediaCommandDispatcher.dispatchCommand("play_pause")
                }) {
                    ZStack {
                        Circle()
                            .fill(hawthornRed)
                            .frame(width: 68, height: 68)
                            .shadow(color: hawthornRed.opacity(0.45), radius: 12, x: 0, y: 4)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("next")
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    lightHaptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("forward")
                }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            Spacer(minLength: 10)
            
            // 4. 底部系统硬件全局音量与静音控制岛
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Button(action: {
                        lightHaptic.impactOccurred()
                        volume = max(0.0, volume - 0.08)
                        isMuted = false
                        MacMediaCommandDispatcher.dispatchCommand("volume_down")
                    }) {
                        Image(systemName: "speaker.minus.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 38)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // 音量滑动刻度条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 6)
                            Capsule()
                                .fill(isMuted ? Color.gray : hawthornRed)
                                .frame(width: geo.size.width * CGFloat(isMuted ? 0.0 : volume), height: 6)
                        }
                        .frame(height: geo.size.height)
                    }
                    .frame(height: 38)
                    
                    Button(action: {
                        lightHaptic.impactOccurred()
                        volume = min(1.0, volume + 0.08)
                        isMuted = false
                        MacMediaCommandDispatcher.dispatchCommand("volume_up")
                    }) {
                        Image(systemName: "speaker.plus.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 38)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button(action: {
                        haptic.impactOccurred()
                        isMuted.toggle()
                        MacMediaCommandDispatcher.dispatchCommand("mute")
                    }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isMuted ? hawthornRed : .white)
                            .frame(width: 42, height: 38)
                            .background(isMuted ? hawthornRed.opacity(0.2) : Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .padding(.horizontal, 16)
            
            // 5. 底部免装软件原生提示
            HStack(spacing: 5) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.green)
                Text("macOS 原生隔空播放接收器直连 · 100% 免装软件")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(.bottom, 12)
        }
        .background(darkCarbon.ignoresSafeArea())
        .onAppear {
            checkAirPlayStatus()
            startWaveAnimation()
        }
        .alert(isPresented: $showHelpAlert) {
            Alert(
                title: Text("隔空播放未就绪"),
                message: Text("请在目标 Mac 开启系统自带的接收功能：\n\n打开【系统设置】->【通用】->【隔空播放与接力】-> 开启【隔空播放接收器】即可直接控制。"),
                dismissButton: .default(Text("好的"))
            )
        }
    }
    
    private func checkAirPlayStatus() {
        let host = MacMediaCommandDispatcher.currentTargetHost
        guard !host.isEmpty else { return }
        MacMediaCommandDispatcher.verifyConnection(host: host) { isOnline in
            self.isAirPlayConnected = isOnline
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
