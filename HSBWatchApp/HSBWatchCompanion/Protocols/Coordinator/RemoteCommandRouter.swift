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
    private var currentMode: HSBRemoteMode { coordinator.currentMode }
    private var isCurrentTargetMac: Bool { coordinator.isCurrentTargetMac }
    
    // MARK: - D-pad & Select
    public func sendDPad(direction: DPadDirection, action: KeyAction = .tap) {
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
        if isCurrentTargetMac {
            if direction == .left {
                MacMediaCommandDispatcher.dispatchCommand("previous")
            } else if direction == .right {
                MacMediaCommandDispatcher.dispatchCommand("next")
            }
        }
        switch currentMode {
        case .screenOnly:
            screenClient.send(command: .button(action: direction.actionName))
        case .nativeOnly:
            let sysKey: SystemKey = {
                switch direction {
                case .up: return .up
                case .down: return .down
                case .left: return .left
                case .right: return .right
                }
            }()
            nativeClient.sendSystemKey(sysKey, action: action)
            let touchDelta: (dx: CGFloat, dy: CGFloat) = {
                switch direction {
                case .up: return (0, -120)
                case .down: return (0, 120)
                case .left: return (-120, 0)
                case .right: return (120, 0)
                }
            }()
            nativeClient.sendTouchEvent(phase: 1, point: CGPoint(x: 500, y: 500))
            nativeClient.sendTouchEvent(phase: 2, point: CGPoint(x: 500 + touchDelta.dx, y: 500 + touchDelta.dy))
            nativeClient.sendTouchEvent(phase: 3, point: CGPoint(x: 500 + touchDelta.dx, y: 500 + touchDelta.dy))
        case .dual:
            if screenClient.isConnected {
                screenClient.send(command: .button(action: direction.actionName))
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
        if HSBTVOSConnectionManager.shared().isConnected {
            HSBTVOSConnectionManager.shared().sendSimulateAction(.select)
        }
        if currentMode == .nativeOnly {
            nativeClient.sendSystemKey(.select, action: action)
            nativeClient.sendTouchEvent(phase: 1, point: CGPoint(x: 500, y: 500))
            nativeClient.sendTouchEvent(phase: 3, point: CGPoint(x: 500, y: 500))
        } else {
            if screenClient.isConnected {
                screenClient.send(command: .button(action: "select"))
            } else if currentMode == .dual {
                nativeClient.sendSystemKey(.select, action: action)
            }
        }
    }
    
    // MARK: - Touchpad & Cursor
    public func sendCursorPan(dx: CGFloat, dy: CGFloat) {
        if currentMode == .nativeOnly {
            let pt = CGPoint(x: 500.0 + dx, y: 500.0 + dy)
            nativeClient.sendTouchEvent(phase: 2, point: pt)
        } else {
            screenClient.send(command: .pan(dx: dx, dy: dy))
        }
    }
    
    public func sendTap(mode: Int = 1, point: CGPoint? = nil) {
        if currentMode == .nativeOnly {
            nativeClient.sendTouchEvent(phase: 1, point: point ?? CGPoint(x: 500, y: 500))
        } else {
            screenClient.send(command: .tap(mode: mode, point: point))
        }
    }
    
    public func sendScroll(dx: CGFloat, dy: CGFloat) {
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
        } else {
            let pt = CGPoint(x: 500.0 + dx, y: 500.0 + dy)
            nativeClient.sendTouchEvent(phase: 2, point: pt)
        }
    }
    
    public func sendDrag(state: DragState, dx: CGFloat, dy: CGFloat) {
        if currentMode != .nativeOnly {
            screenClient.send(command: .drag(state: state, dx: dx, dy: dy))
        }
    }
    
    public func sendZoom(scale: CGFloat) {
        if currentMode != .nativeOnly {
            screenClient.send(command: .zoom(scale: scale))
        }
    }
    
    // MARK: - Text Input
    public func sendTextInput(text: String, isAtomicReplace: Bool = false) {
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
    
    // MARK: - System Keys
    public func sendSystemKey(_ key: SystemKey) {
        if HSBTVOSConnectionManager.shared().isConnected {
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
        switch key {
        case .home:
            if currentMode == .screenOnly {
                screenClient.send(command: .pageAction(action: .home))
            } else {
                nativeClient.sendSystemKey(.home)
            }
        case .menu:
            if currentMode == .screenOnly {
                screenClient.send(command: .button(action: "menu"))
            } else {
                nativeClient.sendSystemKey(.menu)
            }
        case .volumeUp:
            if isCurrentTargetMac {
                MacMediaCommandDispatcher.dispatchCommand("volume_up")
            }
            if currentMode == .nativeOnly {
                nativeClient.sendSystemKey(.volumeUp)
            } else {
                screenClient.send(command: .volume(action: "volume_up", value: nil))
            }
        case .volumeDown:
            if isCurrentTargetMac {
                MacMediaCommandDispatcher.dispatchCommand("volume_down")
            }
            if currentMode == .nativeOnly {
                nativeClient.sendSystemKey(.volumeDown)
            } else {
                screenClient.send(command: .volume(action: "volume_down", value: nil))
            }
        case .mute:
            if isCurrentTargetMac {
                MacMediaCommandDispatcher.dispatchCommand("mute")
            }
            if currentMode == .nativeOnly {
                nativeClient.sendMRPMuteToggle()
            } else {
                screenClient.send(command: .volume(action: "toggle_mute", value: nil))
            }
        case .power:
            nativeClient.sendSystemKey(.power)
        case .playPause:
            if isCurrentTargetMac {
                MacMediaCommandDispatcher.dispatchCommand("play_pause")
            }
            if currentMode == .screenOnly {
                screenClient.send(command: .media(action: .play, value: nil))
            } else {
                nativeClient.sendSystemKey(.playPause)
            }
        case .up:
            if currentMode == .screenOnly {
                sendDPad(direction: .up, action: .tap)
            } else {
                nativeClient.sendSystemKey(.up)
            }
        case .down:
            if currentMode == .screenOnly {
                sendDPad(direction: .down, action: .tap)
            } else {
                nativeClient.sendSystemKey(.down)
            }
        case .left:
            if currentMode == .screenOnly {
                sendDPad(direction: .left, action: .tap)
            } else {
                nativeClient.sendSystemKey(.left)
            }
        case .right:
            if currentMode == .screenOnly {
                sendDPad(direction: .right, action: .tap)
            } else {
                nativeClient.sendSystemKey(.right)
            }
        case .select:
            if currentMode == .screenOnly {
                sendSelect(action: .tap)
            } else {
                nativeClient.sendSystemKey(.select)
            }
        }
    }
    
    // MARK: - Screen Browser Actions
    public func sendPageAction(_ action: PageAction) {
        if currentMode == .nativeOnly {
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
        } else {
            screenClient.send(command: .pageAction(action: action))
        }
    }
}
