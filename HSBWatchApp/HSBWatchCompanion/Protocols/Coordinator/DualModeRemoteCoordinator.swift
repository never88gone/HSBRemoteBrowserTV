//
//  DualModeRemoteCoordinator.swift
//  HSBWatchCompanion
//

import Foundation
import CoreGraphics
import Network

public protocol DualModeRemoteCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didChangeState state: HSBConnectionState)
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didReceiveScreenMessage message: [String: Any])
}

public protocol DualModeRemoteCoordinatorProtocol: AnyObject {
    var currentState: HSBConnectionState { get }
    var currentMode: HSBRemoteMode { get set }
    
    // 导航与 D-pad
    func sendDPad(direction: DPadDirection, action: KeyAction)
    func sendSelect(action: KeyAction)
    
    // 触控板与微操
    func sendCursorPan(dx: CGFloat, dy: CGFloat)
    func sendTap(mode: Int, point: CGPoint?)
    func sendScroll(dx: CGFloat, dy: CGFloat)
    func sendDrag(state: DragState, dx: CGFloat, dy: CGFloat)
    func sendZoom(scale: CGFloat)
    
    // 文本输入
    func sendTextInput(text: String, isAtomicReplace: Bool)
    func sendKeyCommand(key: SpecialKey)
    
    // 系统级控制 (Home, Menu, Volume, Power)
    func sendSystemKey(_ key: SystemKey)
    func wakeDevice(host: String, completion: ((Bool) -> Void)?)
    
    // 专有大屏高级指令
    func sendPageAction(_ action: PageAction)
    func executeJavaScript(_ script: String, completion: ((Result<String, Error>) -> Void)?)
    func sendMediaControl(_ action: MediaAction, value: Double?)
}

public final class DualModeRemoteCoordinator: NSObject, DualModeRemoteCoordinatorProtocol {
    public static let shared = DualModeRemoteCoordinator()
    
    public weak var delegate: DualModeRemoteCoordinatorDelegate?
    
    public let screenClient = HSBBrowserProtocolClient()
    public let nativeClient = AppleTVNativeClient()
    public let stateMachine = HSBConnectionStateMachine()
    
    public var currentMode: HSBRemoteMode = .dual
    
    public var currentState: HSBConnectionState {
        return stateMachine.currentState
    }
    
    public override init() {
        super.init()
        screenClient.delegate = self
        nativeClient.delegate = self
        stateMachine.delegate = self
    }
    
    // MARK: - Connection Lifecycle
    public func connectToScreen(endpoint: nw_endpoint_t, deviceName: String) {
        stateMachine.handle(event: .requestConnect(deviceName: deviceName, mode: currentMode))
        screenClient.connect(to: endpoint, deviceName: deviceName)
    }
    
    public func connectToNative(host: String, deviceName: String) {
        nativeClient.connect(host: host, deviceName: deviceName)
    }
    
    public func disconnectAll() {
        screenClient.disconnect()
        nativeClient.disconnect()
        stateMachine.handle(event: .requestDisconnect(reason: "User requested disconnect"))
    }
    
    // MARK: - D-pad & Select
    public func sendDPad(direction: DPadDirection, action: KeyAction = .tap) {
        switch currentMode {
        case .screenOnly:
            screenClient.send(command: .button(action: direction.actionName))
        case .nativeOnly:
            let sysKey: SystemKey = {
                switch direction {
                case .up: return .volumeUp
                case .down: return .volumeDown
                case .left: return .menu
                case .right: return .home
                }
            }()
            nativeClient.sendSystemKey(sysKey, action: action)
        case .dual:
            if screenClient.isConnected {
                screenClient.send(command: .button(action: direction.actionName))
            } else {
                nativeClient.sendSystemKey(.menu, action: action)
            }
        }
    }
    
    public func sendSelect(action: KeyAction = .tap) {
        if currentMode == .nativeOnly {
            nativeClient.sendSystemKey(.playPause, action: action)
        } else {
            if screenClient.isConnected {
                screenClient.send(command: .button(action: "select"))
            } else if currentMode == .dual {
                nativeClient.sendSystemKey(.playPause, action: action)
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
        if currentMode != .nativeOnly {
            screenClient.send(command: .scroll(dx: dx, dy: dy))
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
            executeJavaScript(script, completion: nil)
        } else {
            let escaped = text.replacingOccurrences(of: "'", with: "\\'")
            let script = "if (document.activeElement) { document.execCommand('insertText', false, '\(escaped)'); }"
            executeJavaScript(script, completion: nil)
        }
    }
    
    public func sendKeyCommand(key: SpecialKey) {
        switch key {
        case .backspace:
            let script = "if (document.activeElement) { document.execCommand('delete'); }"
            executeJavaScript(script, completion: nil)
        case .enter:
            screenClient.send(command: .button(action: "select"))
        case .escape:
            screenClient.send(command: .button(action: "menu"))
        case .space:
            sendTextInput(text: " ")
        }
    }
    
    // MARK: - System Keys
    public func sendSystemKey(_ key: SystemKey) {
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
            if currentMode == .nativeOnly {
                nativeClient.sendSystemKey(.volumeUp)
            } else {
                screenClient.send(command: .volume(action: "volume_up", value: nil))
            }
        case .volumeDown:
            if currentMode == .nativeOnly {
                nativeClient.sendSystemKey(.volumeDown)
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
            nativeClient.sendSystemKey(.power)
        case .playPause:
            if currentMode == .screenOnly {
                screenClient.send(command: .media(action: .play, value: nil))
            } else {
                nativeClient.sendSystemKey(.playPause)
            }
        }
    }
    
    public func wakeDevice(host: String, completion: ((Bool) -> Void)? = nil) {
        nativeClient.wakeDevice(host: host, completion: completion)
    }
    
    // MARK: - Screen Browser Actions
    public func sendPageAction(_ action: PageAction) {
        screenClient.send(command: .pageAction(action: action))
    }
    
    public func executeJavaScript(_ script: String, completion: ((Result<String, Error>) -> Void)? = nil) {
        screenClient.send(command: .executeJS(script: script)) { success in
            if success {
                completion?(.success("dispatched"))
            } else {
                completion?(.failure(NSError(domain: "DualModeCoordinator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Execute JS failed"])))
            }
        }
    }
    
    public func sendMediaControl(_ action: MediaAction, value: Double? = nil) {
        screenClient.send(command: .media(action: action, value: value))
    }
}

// MARK: - Delegates
extension DualModeRemoteCoordinator: HSBBrowserProtocolClientDelegate {
    public func browserClient(_ client: HSBBrowserProtocolClient, didChangeState state: HSBConnectionState) {
        switch state {
        case .ready(let name, let mode):
            stateMachine.handle(event: .socketConnected(deviceName: name, mode: mode))
        case .failed(let err):
            stateMachine.handle(event: .connectionLost(error: err))
        case .disconnected:
            stateMachine.handle(event: .requestDisconnect(reason: "Disconnected"))
        case .connecting(let name, let mode):
            stateMachine.handle(event: .requestConnect(deviceName: name, mode: mode))
        default:
            break
        }
    }
    
    public func browserClient(_ client: HSBBrowserProtocolClient, didReceiveMessage message: [String: Any]) {
        delegate?.coordinator(self, didReceiveScreenMessage: message)
    }
}

extension DualModeRemoteCoordinator: AppleTVNativeClientDelegate {
    public func nativeClient(_ client: AppleTVNativeClient, didChangeState state: HSBConnectionState) {
        if currentMode == .nativeOnly {
            switch state {
            case .ready(let name, let mode):
                stateMachine.handle(event: .socketConnected(deviceName: name, mode: mode))
            case .failed(let err):
                stateMachine.handle(event: .connectionLost(error: err))
            case .disconnected:
                stateMachine.handle(event: .requestDisconnect(reason: "Native disconnected"))
            case .connecting(let name, let mode):
                stateMachine.handle(event: .requestConnect(deviceName: name, mode: mode))
            default:
                break
            }
        }
    }
    
    public func nativeClient(_ client: AppleTVNativeClient, didRequirePINCompletion completion: @escaping (String) -> Void) {
        // PIN 配对回调
    }
}

extension DualModeRemoteCoordinator: HSBConnectionStateMachineDelegate {
    public func stateMachine(_ sm: HSBConnectionStateMachine, didTransitionTo state: HSBConnectionState) {
        delegate?.coordinator(self, didChangeState: state)
    }
}
