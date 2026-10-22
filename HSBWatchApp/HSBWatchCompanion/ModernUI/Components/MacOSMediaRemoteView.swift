//
//  MacOSMediaRemoteView.swift
//  HSBWatchCompanion
//
//  macOS 原生系统与多媒体深度控制中心
//  直接向当前 Mac 电脑内核派发硬件级 HID 事件 (音量 HUD、系统多媒体按键、调度中心、触控板鼠标与光标)。
//

import SwiftUI

public struct MacOSMediaRemoteView: View {
    public let deviceName: String
    public var onDismiss: (() -> Void)?
    
    // 0: 触控鼠标 (最直观、直接控制 macOS 系统), 1: 按键导航, 2: 媒体播放
    @State private var selectedMacMode: Int = 0
    
    // 媒体播放状态
    @State private var isPlaying: Bool = false
    @State private var wavePhase: CGFloat = 0.0
    @State private var isMuted: Bool = false
    @State private var musicStatusText: String = "未检测到播放器，点击可直接启动 Apple Music"
    
    // 触控板拖拽状态
    @State private var lastDragLocation: CGPoint? = nil
    
    private let hawthornRed = Color(red: 224.0 / 255.0, green: 36.0 / 255.0, blue: 56.0 / 255.0)
    private let darkCarbon = Color(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0)
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    public init(deviceName: String = "Mac", onDismiss: (() -> Void)? = nil) {
        self.deviceName = deviceName
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 1. 顶部 Mac 专属终端识别与断开退出控制条
            HStack(spacing: 10) {
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                HStack(spacing: 6) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hawthornRed)
                    Text(deviceName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("系统直控就绪")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            // 2. 模式切换分段：触控鼠标 / 按键导航 / 媒体播放
            Picker("Mac 控制形态", selection: $selectedMacMode) {
                Text("触控鼠标").tag(0)
                Text("按键导航").tag(1)
                Text("媒体播放").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            
            // 3. 动态内容区
            if selectedMacMode == 0 {
                trackpadMousePanel
            } else if selectedMacMode == 1 {
                dpadNavigationPanel
            } else {
                mediaPlaybackPanel
            }
            
            Spacer(minLength: 4)
            
            // 4. 底部系统硬件全局音量与调度控制岛 (在所有模式下均常驻可用)
            globalSystemQuickBar
            
            // 5. 底部协议保障指引卡片
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.green)
                Text("物理级原生 HID 事件直驱 macOS 系统，零模拟器延迟")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }
            .padding(.bottom, 8)
        }
        .background(darkCarbon.ignoresSafeArea())
        .onAppear {
            checkMacStatus()
            startWaveAnimation()
        }
    }
    
    // MARK: - 常驻系统全局硬件控制岛 (音量 HUD、静音、调度中心)
    private var globalSystemQuickBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                lightHaptic.impactOccurred()
                MacMediaCommandDispatcher.dispatchCommand("volume_down")
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "speaker.minus.fill")
                        .font(.system(size: 12))
                    Text("音量 -")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button(action: {
                lightHaptic.impactOccurred()
                isMuted.toggle()
                MacMediaCommandDispatcher.dispatchCommand("mute")
            }) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isMuted ? hawthornRed : .white.opacity(0.9))
                    .frame(width: 44, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button(action: {
                lightHaptic.impactOccurred()
                MacMediaCommandDispatcher.dispatchCommand("volume_up")
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "speaker.plus.fill")
                        .font(.system(size: 12))
                    Text("音量 +")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button(action: {
                haptic.impactOccurred()
                MacMediaCommandDispatcher.dispatchCommand("mission_control")
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 12))
                    Text("调度")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Panel 1: 无线触控板与鼠标 (直接控制 macOS 系统)
    @ViewBuilder
    private var trackpadMousePanel: some View {
        VStack(spacing: 12) {
            // 触控板核心交互区
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                    )
                
                VStack(spacing: 8) {
                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(hawthornRed.opacity(0.8))
                    Text("单指滑动移动 Mac 鼠标光标，轻点左键触发点击")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                    Text("直接向 Mac 系统 HID 队列广播，任何窗口均可交互")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let last = lastDragLocation {
                            let dx = value.location.x - last.x
                            let dy = value.location.y - last.y
                            MacMediaCommandDispatcher.dispatchCommand("pan", params: ["dx": dx * 2.2, "dy": dy * 2.2])
                        }
                        lastDragLocation = value.location
                    }
                    .onEnded { value in
                        if let last = lastDragLocation {
                            let totalDist = hypot(value.location.x - value.startLocation.x, value.location.y - value.startLocation.y)
                            if totalDist < 8 {
                                lightHaptic.impactOccurred()
                                MacMediaCommandDispatcher.dispatchCommand("click")
                            }
                        }
                        lastDragLocation = nil
                    }
            )
            
            // 触控板底座按键排布 (鼠标左键、右键菜单、向上滚动、向下滚动)
            HStack(spacing: 10) {
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("click")
                }) {
                    Text("鼠标左键")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(hawthornRed))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("right_click")
                }) {
                    Text("右键菜单")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    lightHaptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("scroll", params: ["dy": 6])
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    lightHaptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("scroll", params: ["dy": -6])
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Panel 2: 按键轮盘导航 (系统方向键与快捷控制)
    @ViewBuilder
    private var dpadNavigationPanel: some View {
        VStack(spacing: 16) {
            // D-Pad 轮盘
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 220, height: 220)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                
                // 上
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("up")
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 50)
                }
                .buttonStyle(ScaleButtonStyle())
                .offset(y: -75)
                
                // 下
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("down")
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 50)
                }
                .buttonStyle(ScaleButtonStyle())
                .offset(y: 75)
                
                // 左
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("left")
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 60)
                }
                .buttonStyle(ScaleButtonStyle())
                .offset(x: -75)
                
                // 右
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("right")
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 60)
                }
                .buttonStyle(ScaleButtonStyle())
                .offset(x: 75)
                
                // 中心 Select / 回车按键
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("select")
                }) {
                    ZStack {
                        Circle()
                            .fill(hawthornRed)
                            .frame(width: 72, height: 72)
                            .shadow(color: hawthornRed.opacity(0.4), radius: 8, x: 0, y: 2)
                        Text("回车")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .frame(height: 220)
            
            // 快捷控制底座 (返回/ESC、空格 Space、桌面 Mission Control)
            HStack(spacing: 12) {
                Button(action: {
                    lightHaptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("back")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "escape")
                            .font(.system(size: 13, weight: .semibold))
                        Text("ESC 返回")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    lightHaptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("space")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "space")
                            .font(.system(size: 13, weight: .semibold))
                        Text("空格键")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    lightHaptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("home")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 13, weight: .semibold))
                        Text("桌面/调度")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Panel 3: 媒体播放控制台 (兼顾未开播放器时的自动唤起)
    @ViewBuilder
    private var mediaPlaybackPanel: some View {
        VStack(spacing: 16) {
            // 动态黑胶唱片 / 音浪卡片
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .frame(width: 78, height: 78)
                        
                        Circle()
                            .fill(hawthornRed)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: hawthornRed.opacity(0.5), radius: 8, x: 0, y: 0)
                    }
                    
                    // 动态律动音浪条
                    HStack(spacing: 4) {
                        ForEach(0..<12) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(hawthornRed.opacity(0.85))
                                .frame(width: 3.5, height: waveBarHeight(index: i))
                        }
                    }
                    .frame(height: 18)
                    
                    VStack(spacing: 3) {
                        Text(isPlaying ? "macOS 全局媒体控制中" : "macOS 系统媒体控制")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(musicStatusText)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 14)
            }
            .frame(height: 190)
            .padding(.horizontal, 16)
            
            // 一键启动 Apple Music 快捷条
            Button(action: {
                haptic.impactOccurred()
                musicStatusText = "正在唤起 Apple Music 播放器..."
                MacMediaCommandDispatcher.dispatchCommand("open_music")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    isPlaying = true
                    musicStatusText = "Apple Music 已启动并就绪"
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hawthornRed)
                    Text("直接启动 Apple Music 音乐播放器")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                )
            }
            .padding(.horizontal, 16)
            .buttonStyle(ScaleButtonStyle())
            
            // 核心媒体控制按钮群 (上一首、播放/暂停、下一首)
            HStack(spacing: 32) {
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("previous")
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 52, height: 52)
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        Image(systemName: "backward.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    haptic.impactOccurred()
                    isPlaying.toggle()
                    musicStatusText = isPlaying ? "正在向 Mac 发送播放指令" : "已向 Mac 发送暂停指令"
                    MacMediaCommandDispatcher.dispatchCommand("play_pause")
                }) {
                    ZStack {
                        Circle()
                            .fill(hawthornRed)
                            .frame(width: 64, height: 64)
                            .shadow(color: hawthornRed.opacity(0.4), radius: 10, x: 0, y: 3)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    haptic.impactOccurred()
                    MacMediaCommandDispatcher.dispatchCommand("next")
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 52, height: 52)
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.top, 4)
        }
    }
    
    private func checkMacStatus() {
        let host = MacMediaCommandDispatcher.currentTargetHost.isEmpty ? "127.0.0.1" : MacMediaCommandDispatcher.currentTargetHost
        guard let url = URL(string: "http://\(host):49888/status") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let musicRunning = json["music_running"] as? Bool ?? false
                DispatchQueue.main.async {
                    if musicRunning {
                        musicStatusText = "Apple Music 正在 Mac 运行中，已连接"
                        isPlaying = true
                    } else {
                        musicStatusText = "Mac 未检测到运行中的播放器，点击下方可直接启动"
                        isPlaying = false
                    }
                }
            }
        }.resume()
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
