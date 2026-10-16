//
//  DualModeRemoteCoordinatorProtocol.swift
//  HSBWatchCompanion
//

import Foundation
import CoreGraphics

public protocol DualModeRemoteCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didChangeState state: HSBConnectionState)
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didReceiveScreenMessage message: [String: Any])
}

@MainActor
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
    
    // 应用启动与生态调度
    func launchApp(bundleID: String, url: String?, completion: ((Bool) -> Void)?)
    
    // 原生 PIN 码配对提交
    func submitNativePIN(_ pin: String, completion: ((Bool) -> Void)?)
}
