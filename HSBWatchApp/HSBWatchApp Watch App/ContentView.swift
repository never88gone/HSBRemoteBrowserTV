//
//  ContentView.swift
//  HSBWatchApp Watch App
//  糖葫芦腕上遥控器 - 原生 watchOS 交互界面
//

import SwiftUI
import WatchKit
import Combine

func L(_ en: String, _ zh: String) -> String {
    let lang = Locale.preferredLanguages.first ?? Locale.current.identifier
    if lang.lowercased().hasPrefix("zh") {
        return zh
    }
    return en
}

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: 核心 D-Pad 遥控大屏
            RemoteDPadView(motionManager: motionManager)
                .tag(0)

            // Tab 1: 数码表冠网页滚动与缩放
            WebScrollCrownView(motionManager: motionManager)
                .tag(1)

            // Tab 2: 体感手腕光标直驱
            MotionAirMouseView(motionManager: motionManager)
                .tag(2)

            // Tab 3: 大屏媒体与音量控制
            MediaVolumeControlView(motionManager: motionManager)
                .tag(3)
        }
        .tabViewStyle(.page)
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-tab1") {
                selectedTab = 1
            } else if args.contains("-tab2") || args.contains("-tab2Active") {
                selectedTab = 2
                if args.contains("-tab2Active") {
                    motionManager.isServiceRunning = true
                    motionManager.lastAction = L("Flick Confirmed 轻弹确认点击", "轻弹快速确认点击")
                }
            } else if args.contains("-tab3") {
                selectedTab = 3
            } else {
                selectedTab = 0
            }
            // 截图与展示模式默认呈现连通就绪状态
            motionManager.isConnected = true
            motionManager.connectionState = .connected
        }
        .alert(isPresented: $motionManager.showErrorAlert) {
            Alert(
                title: Text(L("Connection Notice", "连接提示")),
                message: Text(motionManager.connectionError ?? L("Unknown Error", "未知状态")),
                dismissButton: .default(Text(L("OK", "确定")))
            )
        }
    }
}

// MARK: - Tab 1: D-Pad 遥控面板
struct RemoteDPadView: View {
    @ObservedObject var motionManager: MotionManager

    private var statusColor: Color {
        switch motionManager.connectionState {
        case .failed, .disconnected: return .orange
        case .connecting: return .yellow
        case .connected: return .green
        }
    }

    private var statusText: String {
        switch motionManager.connectionState {
        case .failed, .disconnected: return L("Ready", "就绪")
        case .connecting: return L("Syncing", "连接中")
        case .connected: return L("Connected", "已连接")
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            // 顶部状态条：状态点与标题居左，右侧彻底留空避让系统原生时钟！
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
                Text(L("Tanghulu", "糖葫芦遥控"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text("· " + statusText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(statusColor)
                Spacer() // 强力垫开，避免任何时钟重叠
            }
            .padding(.horizontal, 4)

            // 核心 D-Pad 十字控制区 (自定义高斯毛玻璃与精确尺寸，告别系统强制撑大)
            VStack(spacing: 3) {
                // 上
                Button(action: { motionManager.sendDpadUp() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // 左 中(OK) 右
                HStack(spacing: 3) {
                    Button(action: { motionManager.sendDpadLeft() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(Color.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: { motionManager.sendSelect() }) {
                        Text("OK")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 28)
                            .background(Color(red: 0.9, green: 0.15, blue: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: { motionManager.sendDpadRight() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(Color.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                // 下
                Button(action: { motionManager.sendDpadDown() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // 底部快捷动作行 (返回 / 主页 / 播放暂停 / 刷新)
            HStack(spacing: 4) {
                Button(action: { motionManager.sendBack() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Color.blue.opacity(0.45))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { motionManager.sendHome() }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Color.orange.opacity(0.45))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { motionManager.sendPlayPause() }) {
                    Image(systemName: "playpause.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Color.green.opacity(0.45))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { motionManager.sendReload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Color.purple.opacity(0.45))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Tab 2: 网页滚轮与表冠直驱
struct WebScrollCrownView: View {
    @ObservedObject var motionManager: MotionManager
    @State private var crownOffset: Double = 0.0
    @State private var lastSentCrown: Double = 0.0

    var body: some View {
        VStack(spacing: 3) {
            Text(L("Web Page Scroll", "网页滚轮平滑滚动"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)

            // 表冠交互视觉指示器
            VStack(spacing: 2) {
                Image(systemName: "digitalcrown.arrow.clockwise.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))

                Text(L("Turn Crown to Scroll", "旋转表冠上下滚动网页"))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
            )
            .focusable()
            .digitalCrownRotation($crownOffset, from: -10000.0, through: 10000.0, by: 1.0, sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
            .onChange(of: crownOffset) { newValue in
                let diff = newValue - lastSentCrown
                if abs(diff) >= 5.0 {
                    motionManager.sendScroll(deltaY: -diff * 6.0)
                    lastSentCrown = newValue
                }
            }

            // 快捷长翻页与页面缩放控制
            HStack(spacing: 4) {
                Button(action: { motionManager.sendScroll(deltaY: 300) }) {
                    Label(L("Page Up", "向上翻页"), systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 8, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button(action: { motionManager.sendScroll(deltaY: -300) }) {
                    Label(L("Page Down", "向下翻页"), systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 8, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }

            HStack(spacing: 4) {
                Button(action: { motionManager.sendZoom(delta: 0.1) }) {
                    Label(L("Zoom In", "网页放大"), systemImage: "plus.magnifyingglass")
                        .font(.system(size: 8, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 20)
                }
                .buttonStyle(.bordered)
                .tint(.gray.opacity(0.4))

                Button(action: { motionManager.sendZoom(delta: -0.1) }) {
                    Label(L("Zoom Out", "网页缩小"), systemImage: "minus.magnifyingglass")
                        .font(.system(size: 8, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 20)
                }
                .buttonStyle(.bordered)
                .tint(.gray.opacity(0.4))
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Tab 3: 体感手腕光标直驱
struct MotionAirMouseView: View {
    @ObservedObject var motionManager: MotionManager

    var body: some View {
        VStack(spacing: 5) {
            Text(L("Air Mouse Cursor", "手腕体感空鼠"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)

            // 体感开关键
            Button(action: {
                if motionManager.isServiceRunning {
                    motionManager.stopMotionUpdates()
                } else {
                    motionManager.startMotionUpdates()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: motionManager.isServiceRunning ? "waveform.path.ecg" : "hand.draw.fill")
                        .font(.system(size: 13))
                    Text(motionManager.isServiceRunning
                         ? L("Stop Cursor", "停止体感光标")
                         : L("Start Air Mouse", "开启手腕光标"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(motionManager.isServiceRunning ? .red : Color(red: 0.9, green: 0.2, blue: 0.2))
            .clipShape(Capsule())

            // 姿态信息卡片
            VStack(spacing: 3) {
                HStack {
                    Text(L("Wrist Tilt", "手腕姿态"))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(motionManager.isServiceRunning ? L("Active 直驱中", "光标直驱中") : L("Paused 待机", "待机"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(motionManager.isServiceRunning ? .green : .gray)
                }

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    Text(L("Latest Action", "最近判定"))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(motionManager.lastAction)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
            )

            // 说明文本
            Text(L("Tilt wrist to move TV cursor, flick wrist to tap", "倾斜手腕平滑移动光标，轻抖手腕快速确认点击"))
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 2)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Tab 4: 大屏媒体与音量控制
struct MediaVolumeControlView: View {
    @ObservedObject var motionManager: MotionManager

    var body: some View {
        VStack(spacing: 5) {
            Text(L("Media & Volume", "大屏音量与媒体"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)

            // 音量控制核心面板
            HStack(spacing: 6) {
                Button(action: { motionManager.sendVolumeDown() }) {
                    Image(systemName: "speaker.minus.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.bordered)
                .tint(.gray.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(spacing: 2) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text(L("Volume 70%", "音量 70%"))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 54, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )

                Button(action: { motionManager.sendVolumeUp() }) {
                    Image(systemName: "speaker.plus.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.bordered)
                .tint(.gray.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 2)

            // 快捷静音与全屏行
            HStack(spacing: 4) {
                Button(action: { motionManager.sendMute() }) {
                    Label(L("Mute", "一键静音"), systemImage: "speaker.slash.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.bordered)
                .tint(.red.opacity(0.7))
                .clipShape(Capsule())

                Button(action: { motionManager.sendToggleFullscreen() }) {
                    Label(L("Fullscreen", "全屏切换"), systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.bordered)
                .tint(.blue.opacity(0.7))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 2)

            // 网页历史前进/后退行
            HStack(spacing: 4) {
                Button(action: { motionManager.sendRemoteAction("page_prev") }) {
                    Label(L("Prev Page", "上一页"), systemImage: "chevron.backward")
                        .font(.system(size: 9, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .buttonStyle(.bordered)
                .tint(.gray.opacity(0.4))

                Button(action: { motionManager.sendRemoteAction("page_next") }) {
                    Label(L("Next Page", "下一页"), systemImage: "chevron.forward")
                        .font(.system(size: 9, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .buttonStyle(.bordered)
                .tint(.gray.opacity(0.4))
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
