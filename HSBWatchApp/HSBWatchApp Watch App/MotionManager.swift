import Foundation
import CoreMotion
import WatchConnectivity
import WatchKit
import Combine

class MotionManager: NSObject, ObservableObject, WCSessionDelegate, WKExtendedRuntimeSessionDelegate {
    private lazy var motionManager = CMMotionManager()
    private var extendedSession: WKExtendedRuntimeSession?
    
    // WCSession State
    @Published var isConnected: Bool = false
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case failed
    }
    @Published var connectionState: ConnectionState = .disconnected
    @Published var statusMessage: String = L("Connecting to iOS...", "正在连接 iOS...")
    
    // Error Handling
    @Published var connectionError: String? = nil
    @Published var showErrorAlert: Bool = false
    
    // Motion State
    @Published var lastAction: String = L("Waiting...", "等待动作...")
    @Published var actionCount: Int = 0 // Track total gestures for the task
    @Published var isServiceRunning: Bool = false
    
    // Background Session State
    @Published var isBackgroundActive: Bool = false
    @Published var backgroundStatusMessage: String = ""
    
    // 各手势独立冷却时间（避免全局死区过于粗暴）
    private var lastFlipUpTime: Date = Date.distantPast
    private var lastFlipDownTime: Date = Date.distantPast
    private var lastShakeTime: Date = Date.distantPast
    private let sameCooldown: TimeInterval = 0.8    // 同一手势重复冷却（优化为0.8秒以便连续打卡）
    private let crossCooldown: TimeInterval = 0.35  // 切换不同手势冷却

    // 滑动窗口缓冲（保留最近 N 帧做峰值检测）
    private struct MotionSample {
        let pitchRate: Double   // 有符号 X 轴（正=向上翻腕）
        let yawRate: Double
        let rollRate: Double
        let totalAccel: Double
    }
    private var motionBuffer: [MotionSample] = []
    private let bufferSize = 25  // 25帧×20ms = 500ms 窗口，配合 50Hz 采样率

    // 识别阈值
    private let flipThreshold: Double = 3.0      // 翻腕角速率阈值 rad/s
    private let dominanceRatio: Double = 1.3     // 主轴相对其他轴的倍数优势（降低严格度容忍人体真实非直线运动）
    private let shakeAccelThreshold: Double = 2.2  // 摇晃加速度阈值 g
    private let shakeRollThreshold: Double = 4.0   // 摇晃角速率阈值 rad/s
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            connectionState = .connecting
            statusMessage = L("Activating Session...", "正在激活通道...")
        } else {
            connectionState = .failed
            connectionError = L("WatchConnectivity is not supported on this device.", "此设备不支持 WatchConnectivity 通讯协议。")
            showErrorAlert = true
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.connectionState = .failed
                self.statusMessage = L("Failed", "连接失败")
                self.connectionError = error.localizedDescription
                self.showErrorAlert = true
                return
            }
            
            if activationState == .activated {
                self.connectionState = .connected
                self.isConnected = true
                self.statusMessage = L("Connected to iOS Companion", "已连接至 iOS 宿主")
            } else {
                self.connectionState = .disconnected
                self.isConnected = false
                self.statusMessage = L("Disconnected", "已断开连接")
            }
        }
    }
    
    // Fallback UI disconnect function
    func disconnect() {
        isConnected = false
        connectionState = .disconnected
        if isServiceRunning {
            stopMotionUpdates()
        }
    }
    
    // MARK: - Motion
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("DeviceMotion is not available on this device.")
            self.connectionError = L("Motion sensors not available on this device.", "此设备不可用运动传感器。")
            self.showErrorAlert = true
            return
        }
        
        // 提升至 50Hz 游戏级采样频率（避免错过高速移动手势波峰）
        motionManager.deviceMotionUpdateInterval = 0.02
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }
            self.processMotion(data)
        }
        isServiceRunning = true
        
        // 申请后台运行权
        startExtendedSession()
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        isServiceRunning = false
        
        // 释放后台会话
        invalidateExtendedSession()
    }
    
    // MARK: - WKExtendedRuntimeSession
    private func startExtendedSession() {
        // 如果已有活跃会话，不重复创建
        if let existing = extendedSession, existing.state == .running {
            return
        }
        
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        extendedSession = session
        print("[ExtendedSession] Requesting background session...")
    }
    
    private func invalidateExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
        DispatchQueue.main.async {
            self.isBackgroundActive = false
            self.backgroundStatusMessage = ""
        }
    }
    
    // MARK: - WKExtendedRuntimeSessionDelegate
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("[ExtendedSession] Background session started successfully.")
        DispatchQueue.main.async {
            self.isBackgroundActive = true
            self.backgroundStatusMessage = L("🌙 Background Active", "🌙 后台运行中（放腕可用）")
        }
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                 didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                 error: Error?) {
        print("[ExtendedSession] Session invalidated. Reason: \(reason.rawValue), Error: \(String(describing: error))")
        DispatchQueue.main.async {
            self.isBackgroundActive = false
            switch reason {
            case .none:
                // 正常结束（用户主动停止）
                self.backgroundStatusMessage = L("Background session ended", "后台会话已结束")
            case .expired:
                // 60分钟到期
                self.backgroundStatusMessage = L("⏰ Session expired (60min limit). Tap Start to resume.", "⏰ 后台时限到期（60分钟），请重新启动")
                // 自动停止陀螺仪避免无效采集
                if self.isServiceRunning {
                    self.motionManager.stopDeviceMotionUpdates()
                    self.isServiceRunning = false
                }
            case .resignedFrontmost:
                // 会话在后台运行中（手腕放下）
                self.backgroundStatusMessage = L("🌙 Background Active", "🌙 后台运行中（放腕可用）")
            case .suppressedBySystem:
                self.backgroundStatusMessage = L("⚠️ Suppressed by system", "⚠️ 被系统中断")
            case .error:
                self.backgroundStatusMessage = L("⚠️ Session error", "⚠️ 后台会话出错")
                if let error = error {
                    print("[ExtendedSession] Error: \(error.localizedDescription)")
                }
            default:
                self.backgroundStatusMessage = L("Background session ended", "后台会话已结束")
            }
        }
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // 即将到期时（距到期约1分钟提醒），播放触觉提示
        print("[ExtendedSession] Session will expire soon.")
        WKInterfaceDevice.current().play(.notification)
        DispatchQueue.main.async {
            self.backgroundStatusMessage = L("⚠️ Session expiring soon...", "⚠️ 后台即将到期，请重新启动")
        }
    }
    
    // MARK: - Motion Processing
    private func processMotion(_ motion: CMDeviceMotion) {
        let now = Date()

        // --- 采集有符号 IMU 数据 ---
        let pitchSigned = motion.rotationRate.x   // 正 = 向上翻腕，负 = 向下翻腕
        let yawSigned   = motion.rotationRate.z
        let rollSigned  = motion.rotationRate.y
        let ua          = motion.userAcceleration
        let totalAccel  = sqrt(ua.x*ua.x + ua.y*ua.y + ua.z*ua.z)

        // 写入滑动窗口
        motionBuffer.append(MotionSample(
            pitchRate: pitchSigned,
            yawRate:   yawSigned,
            rollRate:  rollSigned,
            totalAccel: totalAccel
        ))
        if motionBuffer.count > bufferSize { motionBuffer.removeFirst() }

        // 窗口未满：等待更多数据
        guard motionBuffer.count == bufferSize else { return }

        // --- 500ms 窗口内取各轴峰值（保留符号方向）---
        let peakPitch = motionBuffer.max(by: { abs($0.pitchRate) < abs($1.pitchRate) })!.pitchRate
        let peakRoll  = motionBuffer.max(by: { abs($0.rollRate)  < abs($1.rollRate)  })!.rollRate
        let peakAccel = motionBuffer.map(\.totalAccel).max()!
        let absPitch  = abs(peakPitch)
        let absYaw    = motionBuffer.map({ abs($0.yawRate) }).max()!
        let absRoll   = abs(peakRoll)

        // -------------------------------------------------------
        // 手势 1: 向上翻腕 (pitch 正方向) → flip_up
        // -------------------------------------------------------
        if peakPitch > flipThreshold
            && absPitch > absYaw * dominanceRatio
            && absPitch > absRoll * dominanceRatio {

            let lastOther = max(lastFlipDownTime, lastShakeTime)
            guard now.timeIntervalSince(lastFlipUpTime) > sameCooldown,
                  now.timeIntervalSince(lastOther) > crossCooldown else { return }

            lastFlipUpTime = now
            motionBuffer.removeAll()   // 清空缓冲，防止同帧重复触发
            triggerAction(L("↑ Flip Up", "↑ 向上翻腕"), haptic: .directionUp)
            sendMessage(action: "flip_up")
            return
        }

        // -------------------------------------------------------
        // 手势 2: 向下翻腕 (pitch 负方向) → flip_down
        // -------------------------------------------------------
        if peakPitch < -flipThreshold
            && absPitch > absYaw * dominanceRatio
            && absPitch > absRoll * dominanceRatio {

            let lastOther = max(lastFlipUpTime, lastShakeTime)
            guard now.timeIntervalSince(lastFlipDownTime) > sameCooldown,
                  now.timeIntervalSince(lastOther) > crossCooldown else { return }

            lastFlipDownTime = now
            motionBuffer.removeAll()
            triggerAction(L("↓ Flip Down", "↓ 向下翻腕"), haptic: .directionDown)
            sendMessage(action: "flip_down")
            return
        }

        // -------------------------------------------------------
        // 手势 3: 强烈摇晃 (高加速度 or Roll 剧烈) → shake
        // -------------------------------------------------------
        if peakAccel > shakeAccelThreshold || absRoll > shakeRollThreshold {
            // pitch 未主导（避免翻腕被误识为 shake）
            let pitchDominating = absPitch > absRoll * dominanceRatio && absPitch > flipThreshold
            if !pitchDominating {
                let lastOther = max(lastFlipUpTime, lastFlipDownTime)
                guard now.timeIntervalSince(lastShakeTime) > sameCooldown,
                      now.timeIntervalSince(lastOther) > crossCooldown else { return }

                lastShakeTime = now
                motionBuffer.removeAll()
                triggerAction(L("~ Shake", "~ 摇晃"), haptic: .success)
                sendMessage(action: "shake")
            }
        }
    }
    
    private func triggerAction(_ actionName: String, haptic: WKHapticType) {
        self.lastAction = actionName
        
        DispatchQueue.main.async {
            self.actionCount += 1
        }
        
        // 触觉反馈确认手势已识别
        WKInterfaceDevice.current().play(haptic)
    }
    
    func simulateShake() {
        print("Simulating Shake via UI Button")
        triggerAction("Shake", haptic: .click)
        sendMessage(action: "shake")
    }
    
    private func sendMessage(action: String) {
        guard WCSession.default.activationState == .activated else {
            print("WCSession not activated")
            return
        }
        
        let payload: [String: Any] = ["action": action]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                print("Error sending message to iOS: \(error.localizedDescription)")
                // 降级：走 transferUserInfo 保证送达
                WCSession.default.transferUserInfo(payload)
            }
        } else {
            print("WCSession is not reachable. Using transferUserInfo fallback.")
            WCSession.default.transferUserInfo(payload)
        }
    }
}
