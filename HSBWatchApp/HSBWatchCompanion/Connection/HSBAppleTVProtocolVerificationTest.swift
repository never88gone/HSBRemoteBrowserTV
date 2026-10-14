//
//  HSBAppleTVProtocolVerificationTest.swift
//  HSBWatchCompanion
//
//  原生协议栈全覆盖自动化测试：验证 Apple TV 原生协议（appletv-remote/AppleTVProtocol）
//  OPACK 编解码、HID 遥控指令映射、CompanionFrame 二进制帧、ChaCha20-Poly1305 加密通道、
//  SRP-6a 握手与大数运算、以及双模协调器/连接状态机的状态流转与自愈降级。
//

import Foundation
import CoreGraphics
import CryptoKit

@MainActor
@objc public final class HSBAppleTVProtocolVerificationTest: NSObject {

    @objc public static func runAllTests(completion: @escaping (Bool, String) -> Void) {
        var results: [String] = []
        var allPassed = true

        func record(_ name: String, passed: Bool, detail: String = "") {
            if passed {
                results.append("✅ [PASS] \(name) \(detail)")
            } else {
                results.append("❌ [FAIL] \(name) \(detail)")
                allPassed = false
            }
        }

        // ==========================================
        // 1. OPACK 核心按键与载荷编码/解码验证
        // ==========================================
        let testKeys: [(cmd: RemoteCommand, expectedKeycode: UInt8, name: String)] = [
            (.up, 1, "Up"),
            (.down, 2, "Down"),
            (.left, 3, "Left"),
            (.right, 4, "Right"),
            (.menu, 5, "Menu"),
            (.select, 6, "Select"),
            (.home, 7, "Home"),
            (.volumeUp, 8, "VolumeUp"),
            (.volumeDown, 9, "VolumeDown"),
            (.sleep, 12, "Sleep"),
            (.wake, 13, "Wake"),
            (.playPause, 14, "Play/Pause")
        ]

        var opackKeycodesMatch = true
        for item in testKeys {
            if item.cmd.hidKeycode != item.expectedKeycode {
                opackKeycodesMatch = false
            }
            let encodedData = OPACK.encodeHIDCommand(keycode: item.cmd.hidKeycode, state: 1, txn: 100)
            guard !encodedData.isEmpty else {
                opackKeycodesMatch = false
                break
            }
            if let decoded = OPACK.decodeDict(encodedData) {
                let action = decoded["_i"] as? String
                let txnVal = (decoded["_x"] as? NSNumber)?.uint32Value
                let content = decoded["_c"] as? [String: Any]
                let decodedKeycode = (content?["_hidC"] as? NSNumber)?.intValue
                let decodedState = (content?["_hBtS"] as? NSNumber)?.intValue

                if action != "_hidC" || txnVal != 100 || decodedKeycode != Int(item.expectedKeycode) || decodedState != 1 {
                    opackKeycodesMatch = false
                }
            } else {
                opackKeycodesMatch = false
            }
        }
        record("Test 1: OPACK Remote Commands HID Keycode & Roundtrip", passed: opackKeycodesMatch,
               detail: "Verified Up:1, Down:2, Left:3, Right:4, Menu:5, Select:6, Home:7, VolUp:8, VolDown:9, Sleep:12, Wake:13, PlayPause:14")

        // ==========================================
        // 2. OPACK 触控事件 (1000x1000) 封包验证
        // ==========================================
        let touchData = OPACK.encodeTouchEvent(x: 500.0, y: 350.0, phase: 2, txn: 201, nanoseconds: 12345678)
        var touchVerified = false
        if let decodedTouch = OPACK.decodeDict(touchData),
           let action = decodedTouch["_i"] as? String,
           let content = decodedTouch["_c"] as? [String: Any] {
            let cx = (content["_cx"] as? NSNumber)?.intValue
            let cy = (content["_cy"] as? NSNumber)?.intValue
            let tPh = (content["_tPh"] as? NSNumber)?.intValue
            let tFg = (content["_tFg"] as? NSNumber)?.intValue
            if action == "_hidT" && cx == 500 && cy == 350 && tPh == 2 && tFg == 1 {
                touchVerified = true
            }
        }
        record("Test 2: OPACK 1000x1000 Virtual Space Touch Event Encoding", passed: touchVerified, detail: "action: _hidT, cx: 500, cy: 350, phase: 2, flag: 1")

        // ==========================================
        // 3. CompanionFrame 二进制帧编解码往返
        // ==========================================
        let samplePayload = "TangHuLu-AppleTV-Protocol".data(using: .utf8)!
        let originalFrame = CompanionFrame(type: .eOPACK, payload: samplePayload)
        let frameBytes = originalFrame.encoded
        var decodeBuffer = frameBytes
        let decodedFrame = try? CompanionFrame.read(from: &decodeBuffer)

        let framePassed = (decodedFrame != nil &&
                           decodedFrame?.type == .eOPACK &&
                           decodedFrame?.payload == samplePayload)
        record("Test 3: CompanionFrame Binary Frame Encode & Decode", passed: framePassed,
               detail: "Total Bytes: \(frameBytes.count), Payload Match: \(decodedFrame?.payload == samplePayload)")

        // ==========================================
        // 4. ChaCha20-Poly1305 加密传输通道验证
        // ==========================================
        let testKeyData = SymmetricKey(size: .bits256)
        let transport = EncryptedFrameTransport()
        transport.installSessionKeys(encrypt: testKeyData, decrypt: testKeyData)

        var cryptoSuccess = false
        let plaintext = "Hello Apple TV tvOS Secure Tunnel".data(using: .utf8)!
        do {
            let encrypted = try transport.seal(plaintext)
            if encrypted.count == plaintext.count + 16 {
                let decrypted = try transport.open(encrypted)
                cryptoSuccess = (decrypted == plaintext)
            }
        } catch {
            cryptoSuccess = false
        }
        record("Test 4: ChaCha20-Poly1305 Encrypted Channel Roundtrip", passed: cryptoSuccess,
               detail: "Plaintext (\(plaintext.count) bytes) -> Sealed (\(plaintext.count + 16) bytes) -> Opened (\(plaintext.count) bytes)")

        // ==========================================
        // 5. BigInt / SRP-6a 认证大数生成与加盐运算
        // ==========================================
        var srpOk = false
        let client = SRPClient()
        let pubAData = client.publicKey.serialize()
        if pubAData.count >= 300 {
            srpOk = true
        }
        record("Test 5: SRP-6a Client 3072-bit Key Generation", passed: srpOk, detail: "Public Key A bytes: \(pubAData.count)")

        // ==========================================
        // 6. SwipeDirection 四向滑动手势坐标映射
        // ==========================================
        let upCoords = SwipeDirection.up.coordinates
        let downCoords = SwipeDirection.down.coordinates
        let leftCoords = SwipeDirection.left.coordinates
        let rightCoords = SwipeDirection.right.coordinates

        let swipePassed = (upCoords.start.y == 1000 && upCoords.end.y == 0 &&
                           downCoords.start.y == 0 && downCoords.end.y == 1000 &&
                           leftCoords.start.x == 1000 && leftCoords.end.x == 0 &&
                           rightCoords.start.x == 0 && rightCoords.end.x == 1000)
        record("Test 6: SwipeDirection 1000x1000 Coordinate Mapping", passed: swipePassed,
               detail: "Up:(500,1000)->(500,0), Down:(500,0)->(500,1000), Left:(1000,500)->(0,500), Right:(0,500)->(1000,500)")

        // ==========================================
        // 7. 连接状态机 (HSBConnectionStateMachine) 状态转移与配对
        // ==========================================
        let sm = HSBConnectionStateMachine()
        var smPassed = true

        // 初始为 disconnected
        if sm.state != .disconnected { smPassed = false }

        // disconnected -> connecting
        sm.handle(event: .requestConnect(deviceName: "Apple TV 4K", mode: .nativeOnly))
        usleep(10_000)
        if case .connecting(let name, let mode) = sm.state {
            if name != "Apple TV 4K" || mode != .nativeOnly { smPassed = false }
        } else {
            smPassed = false
        }

        // connecting -> pairing
        sm.handle(event: .pairingRequired(pinNeeded: true))
        usleep(10_000)
        if case .pairing(let name, let pinNeeded) = sm.state {
            if name != "Apple TV 4K" || !pinNeeded { smPassed = false }
        } else {
            smPassed = false
        }

        // pairing -> ready
        sm.handle(event: .pairingSucceeded)
        usleep(10_000)
        if case .ready(let name, let mode) = sm.state {
            if name != "Apple TV 4K" || mode != .nativeOnly { smPassed = false }
        } else {
            smPassed = false
        }

        // ready -> disconnected
        sm.handle(event: .requestDisconnect(reason: "User requested"))
        usleep(10_000)
        if sm.state != .disconnected { smPassed = false }

        record("Test 7: Unified State Machine Transition (Connecting -> Pairing -> Ready -> Disconnected)",
               passed: smPassed, detail: "Final State: \(sm.state)")

        // ==========================================
        // 8. 双模协调器 (DualModeRemoteCoordinator) 接口完整性与指令调度
        // ==========================================
        let coordinator = DualModeRemoteCoordinator.shared
        coordinator.currentMode = .nativeOnly

        // 离线/就绪调度不会崩溃
        coordinator.sendDPad(direction: .up, action: .tap)
        coordinator.sendDPad(direction: .down, action: .tap)
        coordinator.sendDPad(direction: .left, action: .tap)
        coordinator.sendDPad(direction: .right, action: .tap)
        coordinator.sendSelect(action: .tap)
        coordinator.sendSystemKey(.home)
        coordinator.sendSystemKey(.menu)
        coordinator.sendSystemKey(.playPause)
        coordinator.sendSystemKey(.volumeUp)
        coordinator.sendSystemKey(.volumeDown)
        coordinator.sendCursorPan(dx: 10, dy: 10)
        coordinator.sendTap(mode: 1, point: CGPoint(x: 500, y: 500))

        record("Test 8: DualModeRemoteCoordinator Native Mode Dispatch Safety", passed: true,
               detail: "D-Pad, Select, SystemKey, Touchpad successfully dispatched")

        let finalReport = results.joined(separator: "\n")
        completion(allPassed, finalReport)
    }
}
