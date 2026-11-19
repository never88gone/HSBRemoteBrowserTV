//
//  RemoteCommandRouter.swift
//  HSBWatchCompanion
//

import Foundation
import CoreGraphics

@MainActor
public final class RemoteCommandRouter {
    private unowned let coordinator: DualModeRemoteCoordinator
    
    public init(coordinator: DualModeRemoteCoordinator) {
        self.coordinator = coordinator
    }
    
    private var screenClient: HSBBrowserProtocolClient { coordinator.screenClient }
    private var nativeClient: AppleTVNativeClient { coordinator.nativeClient }
    private var androidClient: AndroidTVNativeClient { coordinator.androidClient }
    private var currentMode: HSBRemoteMode { coordinator.currentMode }
    private var isCurrentTargetMac: Bool { coordinator.isCurrentTargetMac }
    
    // 原生 Android TV 触控板滑动导航累加器（无大屏光标时提供 Google TV 风格滑动切焦点）
    private var androidSwipeAccumX: CGFloat = 0
    private var androidSwipeAccumY: CGFloat = 0
    private var androidLastSwipeAt: Date = .distantPast
    
    // MARK: - D-pad & Select
    public func sendDPad(direction: DPadDirection, action: KeyAction = .tap) {
        if isCurrentTargetMac {
            switch direction {
            case .left:
                MacMediaCommandDispatcher.dispatchCommand("backward")
            case .right:
                MacMediaCommandDispatcher.dispatchCommand("forward")
            case .up:
                MacMediaCommandDispatcher.dispatchCommand("volume_up")
            case .down:
                MacMediaCommandDispatcher.dispatchCommand("volume_down")
            }
            return
        }
        if HSBTVOSConnectionManager.shared().isConnected {
            let simAction: HSBRemoteSimulateAction = {
                switch direction {
                case .up: return .up
                case .down: return .down
                case .left: return .left
                case .right: return .right
                }
            }()
            HSBTVOSConnectionManager.shared().sendSimulateAction(simAction)
        }
        switch currentMode {
        case .screenOnly:
            screenClient.send(command: .button(action: direction.actionName))
        case .nativeOnly:
            if androidClient.isConnected {
                androidClient.sendDPad(direction: direction, action: action)
            } else {
                let sysKey: SystemKey = {
                    switch direction {
                    case .up: return .up
                    case .down: return .down
                    case .left: return .left
                    case .right: return .right
                    }
                }()
                nativeClient.sendSystemKey(sysKey, action: action)
            }
        case .dual:
            if screenClient.isConnected {
                screenClient.send(command: .button(action: direction.actionName))
            } else if androidClient.isConnected {
                androidClient.sendDPad(direction: direction, action: action)
            } else {
                let sysKey: SystemKey = {
                    switch direction {
                    case .up: return .up
                    case .down: return .down
                    case .left: return .left
                    case .right: return .right
                    }
                }()
                nativeClient.sendSystemKey(sysKey, action: action)
            }
        }
    }
    
    public func sendSelect(action: KeyAction = .tap) {
        if isCurrentTargetMac {
            MacMediaCommandDispatcher.dispatchCommand("play_pause")
            return
        }
        if HSBTVOSConnectionManager.shared().isConnected {
            HSBTVOSConnectionManager.shared().sendSimulateAction(.select)
        }
        if currentMode == .nativeOnly {
            if androidClient.isConnected {
                androidClient.sendSelect(action: action)
            } else {
                nativeClient.sendSystemKey(.select, action: action)
            }
        } else {
            if screenClient.isConnected {
                screenClient.send(command: .button(action: "select"))
            } else if currentMode == .dual {
                if androidClient.isConnected {
                    androidClient.sendSelect(action: action)
                } else {
                    nativeClient.sendSystemKey(.select, action: action)
                }
            }
        }
    }
    
    // MARK: - Touchpad & Cursor
    public func sendCursorPan(dx: CGFloat, dy: CGFloat) {
        if isCurrentTargetMac { return }
        let legacyMgr = HSBTVOSConnectionManager.shared()
        // 核心修复：只要大屏通道（TLS 1.2专线）连通，必须无条件发送 mac_pan 驱动糖葫芦浏览器光标移动
        if screenClient.isConnected || legacyMgr.isConnected {
            screenClient.send(command: .pan(dx: dx, dy: dy))
            if legacyMgr.isConnected {
                let scaledDx = dx * HSBRemoteConstants.cursorScale
                let scaledDy = dy * HSBRemoteConstants.cursorScale
                legacyMgr.sendPayload([
                    "action": "mac_pan",
                    "dx": scaledDx,
                    "dy": scaledDy
                ])
            }
        }
        // 如果处于原生 Android TV 且大屏专线未连，将触控滑动转换为 D-Pad 焦点切换
        if androidClient.isConnected && !legacyMgr.isConnected && !screenClient.isConnected {
            let now = Date()
            if now.timeIntervalSince(androidLastSwipeAt) > 0.35 {
                androidSwipeAccumX = 0
                androidSwipeAccumY = 0
            }
            androidLastSwipeAt = now
            androidSwipeAccumX += dx
            androidSwipeAccumY += dy
            let threshold: CGFloat = 42.0
            if abs(androidSwipeAccumX) >= threshold || abs(androidSwipeAccumY) >= threshold {
                if abs(androidSwipeAccumX) > abs(androidSwipeAccumY) {
                    androidClient.sendDPad(direction: androidSwipeAccumX > 0 ? .right : .left, action: .tap)
                } else {
                    androidClient.sendDPad(direction: androidSwipeAccumY > 0 ? .down : .up, action: .tap)
                }
                androidSwipeAccumX = 0
                androidSwipeAccumY = 0
            }
            return
        }
        // 如果处于原生 Apple TV 通道且大屏专线未连，向系统发送原生微操触控点
        if nativeClient.isConnected && !legacyMgr.isConnected && !screenClient.isConnected {
            let pt = CGPoint(x: 500.0 + dx, y: 500.0 + dy)
            nativeClient.sendTouchEvent(phase: 2, point: pt)
        }
    }
    
    public func sendTap(mode: Int = 1, point: CGPoint? = nil) {
        if isCurrentTargetMac { return }
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if screenClient.isConnected || legacyMgr.isConnected {
            screenClient.send(command: .tap(mode: mode, point: point))
            var dict: [String: Any] = ["action": "mac_tap", "mode": mode]
            if let pt = point {
                dict["x"] = Double(pt.x)
                dict["y"] = Double(pt.y)
            }
            legacyMgr.sendPayload(dict)
        }
        if androidClient.isConnected && !legacyMgr.isConnected && !screenClient.isConnected {
            if mode == 2 {
                androidClient.sendKey(.back)
            } else {
                androidClient.sendSelect(action: .tap)
            }
            return
        }
        if nativeClient.isConnected && !legacyMgr.isConnected && !screenClient.isConnected {
            nativeClient.sendTouchEvent(phase: 1, point: point ?? CGPoint(x: 500, y: 500))
        }
    }
    
    public func sendScroll(dx: CGFloat, dy: CGFloat) {
        if isCurrentTargetMac { return }
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if screenClient.isConnected || legacyMgr.isConnected {
            screenClient.send(command: .scroll(dx: dx, dy: dy))
            if legacyMgr.isConnected {
                let scaledDx = dx * HSBRemoteConstants.scrollScale
                let scaledDy = dy * HSBRemoteConstants.scrollScale
                legacyMgr.sendPayload([
                    "action": "mac_scroll",
                    "dx": scaledDx,
                    "dy": scaledDy
                ])
            }
        } else if androidClient.isConnected {
            let threshold: CGFloat = 50.0
            androidSwipeAccumX += dx
            androidSwipeAccumY += dy
            if abs(androidSwipeAccumY) >= threshold {
                androidClient.sendDPad(direction: androidSwipeAccumY > 0 ? .down : .up, action: .tap)
                androidSwipeAccumY = 0
                androidSwipeAccumX = 0
            } else if abs(androidSwipeAccumX) >= threshold {
                androidClient.sendDPad(direction: androidSwipeAccumX > 0 ? .right : .left, action: .tap)
                androidSwipeAccumX = 0
                androidSwipeAccumY = 0
            }
        } else {
            let pt = CGPoint(x: 500.0 + dx, y: 500.0 + dy)
            nativeClient.sendTouchEvent(phase: 2, point: pt)
        }
    }
    
    public func sendDrag(state: DragState, dx: CGFloat, dy: CGFloat) {
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if screenClient.isConnected || legacyMgr.isConnected {
            screenClient.send(command: .drag(state: state, dx: dx, dy: dy))
            if legacyMgr.isConnected {
                legacyMgr.sendPayload([
                    "action": "mac_drag",
                    "state": state.stringValue,
                    "dx": Double(dx),
                    "dy": Double(dy)
                ])
            }
        }
    }
    
    public func sendZoom(scale: CGFloat) {
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if screenClient.isConnected || legacyMgr.isConnected {
            screenClient.send(command: .zoom(scale: scale))
            if legacyMgr.isConnected {
                legacyMgr.sendPayload(["action": "zoom", "scale": Double(scale)])
            }
        }
    }
    
    // MARK: - Text Input
    public func sendTextInput(text: String, isAtomicReplace: Bool = false) {
        if isCurrentTargetMac { return }
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if androidClient.isConnected && !screenClient.isConnected && !legacyMgr.isConnected {
            androidClient.sendText(text)
            return
        }
        if isAtomicReplace {
            let script = "if (document.activeElement && 'value' in document.activeElement) { document.activeElement.value = '\(text)'; document.activeElement.dispatchEvent(new Event('input', {bubbles:true})); }"
            coordinator.executeJavaScript(script, completion: nil)
        } else {
            let escaped = text.replacingOccurrences(of: "'", with: "\\'")
            let script = "if (document.activeElement) { document.execCommand('insertText', false, '\(escaped)'); }"
            coordinator.executeJavaScript(script, completion: nil)
        }
    }
    
    public func sendKeyCommand(key: SpecialKey) {
        if isCurrentTargetMac {
            switch key {
            case .enter, .space:
                MacMediaCommandDispatcher.dispatchCommand("play_pause")
            case .escape:
                MacMediaCommandDispatcher.dispatchCommand("mute")
            case .backspace:
                break
            }
            return
        }
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if androidClient.isConnected && (currentMode == .nativeOnly || (!screenClient.isConnected && !legacyMgr.isConnected)) {
            androidClient.sendSpecialKey(key)
            return
        }
        if currentMode == .nativeOnly {
            switch key {
            case .enter:
                nativeClient.sendSystemKey(.select)
            case .escape:
                nativeClient.sendSystemKey(.menu)
            case .backspace, .space:
                break
            }
        } else {
            switch key {
            case .backspace:
                let script = "if (document.activeElement) { document.execCommand('delete'); }"
                coordinator.executeJavaScript(script, completion: nil)
            case .enter:
                screenClient.send(command: .button(action: "select"))
            case .escape:
                screenClient.send(command: .button(action: "menu"))
            case .space:
                sendTextInput(text: " ")
            }
        }
    }
    
    // MARK: - System Keys (全量支持短按、长按按下/释放动作)
    public func sendSystemKey(_ key: SystemKey, action: KeyAction = .tap) {
        if isCurrentTargetMac {
            switch key {
            case .home:
                MacMediaCommandDispatcher.dispatchCommand("home")
            case .menu:
                MacMediaCommandDispatcher.dispatchCommand("back")
            case .volumeUp:
                MacMediaCommandDispatcher.dispatchCommand("volume_up")
            case .volumeDown:
                MacMediaCommandDispatcher.dispatchCommand("volume_down")
            case .mute:
                MacMediaCommandDispatcher.dispatchCommand("mute")
            case .playPause:
                MacMediaCommandDispatcher.dispatchCommand("play_pause")
            case .up:
                MacMediaCommandDispatcher.dispatchCommand("up")
            case .down:
                MacMediaCommandDispatcher.dispatchCommand("down")
            case .left:
                MacMediaCommandDispatcher.dispatchCommand("left")
            case .right:
                MacMediaCommandDispatcher.dispatchCommand("right")
            case .select:
                MacMediaCommandDispatcher.dispatchCommand("select")
            case .power:
                MacMediaCommandDispatcher.dispatchCommand("mute")
            }
            return
        }
        if HSBTVOSConnectionManager.shared().isConnected && action == .tap {
            switch key {
            case .home:
                HSBTVOSConnectionManager.shared().sendSimulateAction(.pageHome)
            case .menu:
                HSBTVOSConnectionManager.shared().sendSimulateAction(.menu)
            case .volumeUp:
                HSBTVOSConnectionManager.shared().sendSimulateAction(.volumeUp)
            case .volumeDown:
                HSBTVOSConnectionManager.shared().sendSimulateAction(.volumeDown)
            case .mute:
                HSBTVOSConnectionManager.shared().sendSimulateAction(.toggleMute)
            case .playPause:
                HSBTVOSConnectionManager.shared().sendSimulateAction(.play)
            default:
                break
            }
        }
        
        // 若连接着原生 Android TV，直接优先透传原生系统指令（支持完整短按与长按）
        if androidClient.isConnected {
            let shouldUseAndroidNative: Bool = {
                if currentMode == .nativeOnly || (!screenClient.isConnected && !HSBTVOSConnectionManager.shared().isConnected) {
                    return true
                }
                // 在双模中，硬件音量、静音、电源始终交由 Android TV 系统底层协议执行
                switch key {
                case .volumeUp, .volumeDown, .mute, .power:
                    return true
                default:
                    return false
                }
            }()
            if shouldUseAndroidNative {
                androidClient.sendSystemKey(key, action: action)
                return
            }
        }
        
        switch key {
        case .home:
            if currentMode == .screenOnly {
                screenClient.send(command: .pageAction(action: .home))
            } else {
                nativeClient.sendSystemKey(.home, action: action)
            }
        case .menu:
            if currentMode == .screenOnly {
                screenClient.send(command: .button(action: "menu"))
            } else {
                nativeClient.sendSystemKey(.menu, action: action)
            }
        case .volumeUp:
            if currentMode == .nativeOnly {
                nativeClient.sendSystemKey(.volumeUp, action: action)
            } else {
                screenClient.send(command: .volume(action: "volume_up", value: nil))
            }
        case .volumeDown:
            if currentMode == .nativeOnly {
                nativeClient.sendSystemKey(.volumeDown, action: action)
            } else {
                screenClient.send(command: .volume(action: "volume_down", value: nil))
            }
        case .mute:
            if currentMode == .nativeOnly {
                nativeClient.sendMRPMuteToggle()
            } else {
                screenClient.send(command: .volume(action: "toggle_mute", value: nil))
            }
        case .power:
            nativeClient.sendSystemKey(.power, action: action)
        case .playPause:
            if currentMode == .screenOnly {
                screenClient.send(command: .media(action: .play, value: nil))
            } else {
                nativeClient.sendSystemKey(.playPause, action: action)
            }
        case .up:
            nativeClient.sendSystemKey(.up, action: action)
        case .down:
            nativeClient.sendSystemKey(.down, action: action)
        case .left:
            nativeClient.sendSystemKey(.left, action: action)
        case .right:
            nativeClient.sendSystemKey(.right, action: action)
        case .select:
            nativeClient.sendSystemKey(.select, action: action)
        }
    }
    
    /// 发送系统按键真实长按手势（按下并持续 duration 秒后自动松开，tvOS 原生支持长按响应）
    public func sendLongPressKey(_ key: SystemKey, duration: TimeInterval = 0.8) {
        sendSystemKey(key, action: .press)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.sendSystemKey(key, action: .release)
        }
    }
    
    /// 发送确定/OK 键真实长按手势（呼出上下文菜单、编辑模式）
    public func sendLongPressSelect(duration: TimeInterval = 0.8) {
        sendSelect(action: .press)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.sendSelect(action: .release)
        }
    }
    
    // MARK: - Screen Browser Actions
    public func sendPageAction(_ action: PageAction) {
        let legacyMgr = HSBTVOSConnectionManager.shared()
        // 核心修复：网页导航按钮专门控制大屏糖葫芦浏览器，绝不能转译成 tvOS 的退出 Menu 或主屏 Home
        if screenClient.isConnected || legacyMgr.isConnected {
            screenClient.send(command: .pageAction(action: action))
            if legacyMgr.isConnected {
                switch action {
                case .back:
                    legacyMgr.sendSimulateAction(.pageBack)
                case .forward:
                    legacyMgr.sendSimulateAction(.pageForward)
                case .reload:
                    legacyMgr.sendSimulateAction(.pageReload)
                case .home:
                    legacyMgr.sendSimulateAction(.pageHome)
                }
            }
        } else if androidClient.isConnected {
            switch action {
            case .back:
                androidClient.sendKey(.back)
            case .forward:
                androidClient.sendDPad(direction: .right, action: .tap)
            case .reload:
                androidClient.sendKey(.refresh)
            case .home:
                androidClient.sendKey(.home)
            }
        } else {
            // 降级：仅在大屏通道未连接时，转译为系统按键
            switch action {
            case .back:
                nativeClient.sendSystemKey(.menu)
            case .forward:
                sendDPad(direction: .right, action: .tap)
            case .reload:
                sendSelect(action: .tap)
            case .home:
                nativeClient.sendSystemKey(.home)
            }
        }
    }
}
