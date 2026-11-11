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
    public var isWideDuo: Bool = false
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
    
    public init(deviceName: String = "Mac", isWideDuo: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.deviceName = deviceName
        self.isWideDuo = isWideDuo
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        Group {
            if isWideDuo {
                wideDuoBody
            } else {
                compactBody
            }
        }
        .onAppear {
            checkAirPlayStatus()
            startWaveAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBShowMacAirPlayHelpNotification"))) { _ in
            showHelpAlert = true
        }
        .alert(isPresented: $showHelpAlert) {
            Alert(
                title: Text("macOS 原生隔空播放直连"),
                message: Text("请在目标 Mac 开启系统自带接收功能：\n\n打开【系统设置】->【通用】->【隔空播放与接力】-> 开启【隔空播放接收器】即可无线控制多媒体、曲目与音量。"),
                dismissButton: .default(Text("好的"))
            )
        }
    }
    
    // MARK: - iPhone Duo 展开态双栏视觉与控台
    private var wideDuoBody: some View {
        HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
            // === 左半屏：沉浸律动黑胶声波视觉台 + 免装引导卡 ===
            VStack(spacing: 14) {
                VStack(spacing: 5) {
                    Text("NOW PLAYING · AIRPLAY AUDIO")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(DuoPalette.hawthornRed)
                        .tracking(1.1)
                    Text("macOS 原生系统音频直推")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DuoPalette.textPrimary)
                }
                .padding(.top, 14)
                
                Spacer(minLength: 6)
                
                // 大号发光黑胶音符盘
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    hawthornRed.opacity(0.32),
                                    hawthornRed.opacity(0.08),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 10,
                                endRadius: 124
                            )
                        )
                        .frame(width: 236, height: 236)
                    
                    Circle()
                        .fill(Color(white: 0.10))
                        .frame(width: 196, height: 196)
                        .overlay(Circle().stroke(DuoPalette.strokeBright, lineWidth: 2))
                    
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(width: 160, height: 160)
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        .frame(width: 126, height: 126)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 62, weight: .semibold))
                        .foregroundColor(isPlaying ? hawthornRed : Color.white.opacity(0.38))
                        .scaleEffect(isPlaying ? 1.07 : 0.96)
                        .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isPlaying)
                }
                
                // 实时通道状态胶囊
                HStack(spacing: 8) {
                    Circle()
                        .fill(DuoPalette.readyGreen)
                        .frame(width: 7, height: 7)
                    Text("Port 7000 · 系统音频与快捷键毫秒级通道")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(DuoPalette.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(DuoPalette.cardElevated))
                .overlay(Capsule().stroke(DuoPalette.stroke, lineWidth: 1))
                
                // 16 阶实时朱砂红频谱律动条
                HStack(spacing: 5) {
                    ForEach(0..<16, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(isPlaying ? DuoPalette.accentRed.opacity(0.9) : Color.white.opacity(0.22))
                            .frame(width: 5, height: wideWaveBarHeight(index: i))
                            .animation(.easeInOut(duration: 0.25), value: wavePhase)
                    }
                }
                .frame(height: 44)
                
                Text(isPlaying ? "正在通过隔空播放隧道同步音频脉冲" : "已就绪 · 点击右侧主控立即控制 Mac 媒体")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DuoPalette.textSecondary)
                    .lineLimit(1)
                
                Spacer(minLength: 6)
                
                // 内置原生低延迟说明子卡
                Button {
                    lightHaptic.impactOccurred()
                    showHelpAlert = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "macbook.and.iphone")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(DuoPalette.readyGreen)
                            Text("原生系统级低延迟直连")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(DuoPalette.textPrimary)
                            Spacer()
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                                .foregroundColor(DuoPalette.textMuted)
                        }
                        Text("无需安装桌面端插件。支持全系统播放器、Music、YouTube、Safari 与 IINA 硬件媒体键及主音量直控。")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundColor(DuoPalette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .duoCard(cornerRadius: 16, fill: DuoPalette.cardElevated, stroke: DuoPalette.stroke)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .duoCard()
            
            // === 右半屏：上播放与音量双卡片 (满宽) + 下 L 型快捷动作 (让位侧边栏) ===
            VStack(spacing: 14) {
                // 1. 多媒体播放控台卡
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("多媒体播放控台")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(DuoPalette.textSecondary)
                        Spacer()
                        Text(isPlaying ? "播放脉冲同步中" : "无线直连就绪")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isPlaying ? DuoPalette.readyGreen : DuoPalette.textMuted)
                    }
                    
                    Spacer(minLength: 4)
                    
                    // 大圆主控区：上一首 | 播放/暂停 | 下一首
                    HStack(spacing: 22) {
                        Spacer()
                        Button(action: triggerPrevious) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 58, height: 58)
                                .background(Circle().fill(DuoPalette.cardElevated))
                                .overlay(Circle().stroke(DuoPalette.stroke, lineWidth: 1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("mac_media_previous_button")
                        
                        Button(action: triggerPlayPause) {
                            ZStack {
                                Circle()
                                    .fill(DuoPalette.accentRed.opacity(0.2))
                                    .frame(width: 102, height: 102)
                                Circle()
                                    .fill(hawthornRed)
                                    .frame(width: 82, height: 82)
                                    .shadow(color: hawthornRed.opacity(0.45), radius: 14, x: 0, y: 5)
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("mac_media_play_pause_button")
                        
                        Button(action: triggerNext) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 58, height: 58)
                                .background(Circle().fill(DuoPalette.cardElevated))
                                .overlay(Circle().stroke(DuoPalette.stroke, lineWidth: 1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("mac_media_next_button")
                        Spacer()
                    }
                    
                    Spacer(minLength: 4)
                    
                    // 双宽胶囊：快退 10s / 快进 10s
                    HStack(spacing: 12) {
                        Button(action: triggerBackward) {
                            HStack(spacing: 8) {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("快退 10s")
                                    .font(.system(size: 13.5, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .duoCard(cornerRadius: 14, fill: DuoPalette.cardElevated, stroke: DuoPalette.stroke)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("mac_media_backward_button")
                        
                        Button(action: triggerForward) {
                            HStack(spacing: 8) {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("快进 10s")
                                    .font(.system(size: 13.5, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .duoCard(cornerRadius: 14, fill: DuoPalette.cardElevated, stroke: DuoPalette.stroke)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("mac_media_forward_button")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .duoCard()
                
                // 2. Mac 硬件主音量输出卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Mac 硬件主音量输出")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(DuoPalette.textSecondary)
                        Spacer()
                        Text(isMuted ? "已静音" : "\(Int(round(volume * 100)))%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(isMuted ? DuoPalette.textMuted : hawthornRed)
                    }
                    
                    // 粗粒度可视化音量刻度推槽
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DuoPalette.cardElevated)
                                .frame(height: 16)
                            Capsule()
                                .fill(isMuted ? Color.gray : hawthornRed)
                                .frame(width: max(16, geo.size.width * CGFloat(isMuted ? 0.0 : volume)), height: 16)
                        }
                        .frame(height: geo.size.height)
                    }
                    .frame(height: 22)
                    
                    // 减小 / 静音 / 增大三联大键
                    HStack(spacing: 10) {
                        Button(action: triggerVolumeDown) {
                            VStack(spacing: 4) {
                                Image(systemName: "speaker.minus.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("减小")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .duoCard(cornerRadius: 13, fill: DuoPalette.cardElevated, stroke: DuoPalette.stroke)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("mac_volume_down_button")
                        
                        Button(action: triggerMute) {
                            VStack(spacing: 4) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(isMuted ? "已静音" : "静音")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(isMuted ? DuoPalette.accentRed : .white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .duoCard(
                                cornerRadius: 13,
                                fill: isMuted ? DuoPalette.accentRed.opacity(0.18) : DuoPalette.cardElevated,
                                stroke: isMuted ? DuoPalette.accentRed.opacity(0.45) : DuoPalette.stroke
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("mac_volume_mute_button")
                        
                        Button(action: triggerVolumeUp) {
                            VStack(spacing: 4) {
                                Image(systemName: "speaker.plus.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("增大")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .duoCard(cornerRadius: 13, fill: DuoPalette.cardElevated, stroke: DuoPalette.stroke)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("mac_volume_up_button")
                    }
                }
                .padding(16)
                .duoCard()
                
                // 3. 右下左翼 L 型快捷控制动作卡 (右侧让位给 4 键侧边栏)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("快捷控制动作")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(DuoPalette.textSecondary)
                            Spacer()
                            Text("端口 7000 实时直连")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(DuoPalette.readyGreen)
                        }
                        
                        Button {
                            lightHaptic.impactOccurred()
                            NotificationCenter.default.post(name: Notification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(DuoPalette.brandBlue.opacity(0.16))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "keyboard")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(DuoPalette.brandBlue)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("远程文字键入")
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("向 Mac 搜索栏发送文本")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(DuoPalette.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DuoPalette.textMuted)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .duoCard(cornerRadius: 14, fill: DuoPalette.cardElevated, stroke: DuoPalette.stroke)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button {
                            lightHaptic.impactOccurred()
                            showHelpAlert = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(DuoPalette.readyGreen.opacity(0.16))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(DuoPalette.readyGreen)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("隔空播放协议说明")
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text("查看免装软件兼容说明与音频通道帮助")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(DuoPalette.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(DuoPalette.textMuted)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .duoCard(cornerRadius: 14, fill: DuoPalette.cardElevated, stroke: DuoPalette.stroke)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button(action: disconnectMac) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(DuoPalette.accentRed.opacity(0.18))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(DuoPalette.accentRed)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("断开直连返回")
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(DuoPalette.accentRed)
                                    Text("返回大屏硬件设备中心")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(DuoPalette.textSecondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .duoCard(
                                cornerRadius: 14,
                                fill: DuoPalette.accentRed.opacity(0.14),
                                stroke: DuoPalette.accentRed.opacity(0.38)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .duoCard()
                    
                    Spacer()
                        .frame(width: DuoMetrics.sidebarReserveWidth - DuoMetrics.trailingPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    // MARK: - 普通单屏 / 外屏折叠态视觉与控台 (安全避让顶栏状态区)
    private var compactBody: some View {
        VStack(spacing: 16) {
            // 1. 顶部 Mac 终端识别与原生隔空播放状态条 (预留 10pt 顶距，坚决杜绝状态栏与灵动岛遮挡)
            HStack(spacing: 8) {
                Button(action: disconnectMac) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("断开")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("mac_disconnect_button")
                
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
                    ForEach(0..<12, id: \.self) { i in
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
            
            // 3. 核心播放控制排组
            HStack(spacing: 16) {
                Button(action: triggerBackward) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("mac_media_backward_button")
                
                Button(action: triggerPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("mac_media_previous_button")
                
                Button(action: triggerPlayPause) {
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
                .accessibilityIdentifier("mac_media_play_pause_button")
                
                Button(action: triggerNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("mac_media_next_button")
                
                Button(action: triggerForward) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("mac_media_forward_button")
            }
            
            Spacer(minLength: 10)
            
            // 4. 底部系统硬件全局音量与静音控制岛
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Button(action: triggerVolumeDown) {
                        Image(systemName: "speaker.minus.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 38)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("mac_volume_down_button")
                    
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
                    
                    Button(action: triggerVolumeUp) {
                        Image(systemName: "speaker.plus.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 38)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("mac_volume_up_button")
                    
                    Button(action: triggerMute) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isMuted ? hawthornRed : .white)
                            .frame(width: 42, height: 38)
                            .background(isMuted ? hawthornRed.opacity(0.2) : Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("mac_volume_mute_button")
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
    }
    
    // MARK: - 共享真实事件动作
    private func disconnectMac() {
        haptic.impactOccurred()
        DualModeRemoteCoordinator.shared.disconnectAll()
        onDismiss?()
        NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
    }
    
    private func triggerBackward() {
        lightHaptic.impactOccurred()
        MacMediaCommandDispatcher.dispatchCommand("backward")
    }
    
    private func triggerForward() {
        lightHaptic.impactOccurred()
        MacMediaCommandDispatcher.dispatchCommand("forward")
    }
    
    private func triggerPrevious() {
        haptic.impactOccurred()
        MacMediaCommandDispatcher.dispatchCommand("previous")
    }
    
    private func triggerNext() {
        haptic.impactOccurred()
        MacMediaCommandDispatcher.dispatchCommand("next")
    }
    
    private func triggerPlayPause() {
        haptic.impactOccurred()
        isPlaying.toggle()
        MacMediaCommandDispatcher.dispatchCommand("play_pause")
    }
    
    private func triggerVolumeDown() {
        lightHaptic.impactOccurred()
        volume = max(0.0, volume - 0.08)
        isMuted = false
        MacMediaCommandDispatcher.dispatchCommand("volume_down")
    }
    
    private func triggerVolumeUp() {
        lightHaptic.impactOccurred()
        volume = min(1.0, volume + 0.08)
        isMuted = false
        MacMediaCommandDispatcher.dispatchCommand("volume_up")
    }
    
    private func triggerMute() {
        haptic.impactOccurred()
        isMuted.toggle()
        MacMediaCommandDispatcher.dispatchCommand("mute")
    }
    
    private func wideWaveBarHeight(index: Int) -> CGFloat {
        if !isPlaying { return 6.0 }
        let pattern: [CGFloat] = [10, 22, 34, 18, 28, 42, 22, 36, 44, 24, 34, 20, 30, 22, 14, 10]
        let base = pattern[index % pattern.count]
        let factor = (CGFloat(index % 3) * 0.16 + 0.84)
        return wavePhase > 0.5 ? base * factor : max(8, base * 0.55)
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

#if DEBUG
#Preview("Mac 隔空播放遥控台 · 折叠窄屏") {
    DuoPreviewContainer(expandedDuo: false) {
        MacOSMediaRemoteView(deviceName: "never88gone的 Mac Studio", isWideDuo: false)
    }
}

#Preview("Mac 隔空播放遥控台 · iPhone Duo 双栏") {
    DuoPreviewContainer(expandedDuo: true) {
        MacOSMediaRemoteView(deviceName: "never88gone的 Mac Studio", isWideDuo: true)
    }
}
#endif
