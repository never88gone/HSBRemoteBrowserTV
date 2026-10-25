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
            // Tab 1: 核心 D-Pad 遥控大屏
            RemoteDPadView(motionManager: motionManager)
                .tag(0)

            // Tab 2: 数码表冠网页滚动与缩放
            WebScrollCrownView(motionManager: motionManager)
                .tag(1)

            // Tab 3: 体感手腕光标直驱
            MotionAirMouseView(motionManager: motionManager)
                .tag(2)
        }
        .tabViewStyle(.page)
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-tab1") {
                selectedTab = 1
            } else if args.contains("-tab2") {
                selectedTab = 2
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
        case .failed, .disconnected: return L("Ready", "大屏就绪")
        case .connecting: return L("Syncing...", "正在连接...")
        case .connected: return L("Connected", "已连接")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                // 顶部状态条
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(L("Tanghulu", "糖葫芦遥控"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(statusText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 4)

                // 核心 D-Pad 十字控制区
                VStack(spacing: 3) {
                    // 上
                    Button(action: { motionManager.sendDpadUp() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // 左 中(OK) 右
                    HStack(spacing: 3) {
                        Button(action: { motionManager.sendDpadLeft() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button(action: { motionManager.sendSelect() }) {
                            Text("OK")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 32)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.9, green: 0.15, blue: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button(action: { motionManager.sendDpadRight() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 下
                    Button(action: { motionManager.sendDpadDown() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.vertical, 1)

                // 底部快捷动作行 (返回 / 主页 / 播放暂停 / 刷新)
                HStack(spacing: 4) {
                    Button(action: { motionManager.sendBack() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue.opacity(0.45))
                    .clipShape(Capsule())

                    Button(action: { motionManager.sendHome() }) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange.opacity(0.45))
                    .clipShape(Capsule())

                    Button(action: { motionManager.sendPlayPause() }) {
                        Image(systemName: "playpause.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green.opacity(0.45))
                    .clipShape(Capsule())

                    Button(action: { motionManager.sendReload() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple.opacity(0.45))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Tab 2: 网页滚轮与表冠直驱
struct WebScrollCrownView: View {
    @ObservedObject var motionManager: MotionManager
    @State private var crownOffset: Double = 0.0
    @State private var lastSentCrown: Double = 0.0

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(L("Web Page Scroll", "网页滚轮平滑滚动"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 2)

                // 表冠交互视觉指示器
                VStack(spacing: 4) {
                    Image(systemName: "digitalcrown.arrow.clockwise.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 0.9, green: 0.2, blue: 0.2))

                    Text(L("Turn Digital Crown", "旋转表冠上下滚动网页"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )
                .focusable()
                .digitalCrownRotation($crownOffset, from: -10000.0, through: 10000.0, by: 1.0, sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
                .onChange(of: crownOffset) { newValue in
                    let diff = newValue - lastSentCrown
                    if abs(diff) >= 5.0 {
                        // 累积达 5 像素滚动发送至 TV
                        motionManager.sendScroll(deltaY: -diff * 6.0)
                        lastSentCrown = newValue
                    }
                }

                // 快捷长翻页与页面缩放控制
                HStack(spacing: 6) {
                    Button(action: { motionManager.sendScroll(deltaY: 300) }) {
                        Label(L("Page Up", "向上翻页"), systemImage: "arrow.up.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button(action: { motionManager.sendScroll(deltaY: -300) }) {
                        Label(L("Page Down", "向下翻页"), systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }

                HStack(spacing: 6) {
                    Button(action: { motionManager.sendZoom(delta: 0.1) }) {
                        Label(L("Zoom In", "网页放大"), systemImage: "plus.magnifyingglass")
                            .font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray.opacity(0.4))

                    Button(action: { motionManager.sendZoom(delta: -0.1) }) {
                        Label(L("Zoom Out", "网页缩小"), systemImage: "minus.magnifyingglass")
                            .font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Tab 3: 体感手腕光标直驱
struct MotionAirMouseView: View {
    @ObservedObject var motionManager: MotionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(L("Air Mouse Cursor", "手腕体感空鼠"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 2)

                // 体感开关键
                Button(action: {
                    if motionManager.isServiceRunning {
                        motionManager.stopMotionUpdates()
                    } else {
                        motionManager.startMotionUpdates()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: motionManager.isServiceRunning ? "waveform.path.ecg" : "hand.draw.fill")
                            .font(.system(size: 14))
                        Text(motionManager.isServiceRunning
                             ? L("Stop Cursor", "停止体感光标")
                             : L("Start Air Mouse", "开启手腕光标"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.borderedProminent)
                .tint(motionManager.isServiceRunning ? .red : Color(red: 0.9, green: 0.2, blue: 0.2))
                .clipShape(Capsule())

                // 姿态信息卡片
                VStack(spacing: 4) {
                    HStack {
                        Text(L("Wrist Tilt", "手腕倾斜"))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(motionManager.isServiceRunning ? L("Active 直驱中", "直驱中") : L("Paused 待机", "待机"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(motionManager.isServiceRunning ? .green : .gray)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    HStack {
                        Text(L("Latest Action", "最近判定"))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(motionManager.lastAction)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )

                // 说明文本
                Text(L("Tilt wrist to control TV cursor, flick wrist to click", "倾斜手腕平滑移动电视光标，轻抖手腕快速确认点击"))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 6)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
