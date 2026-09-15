//
//  HSBConnectionStateMachine.swift
//  HSBWatchCompanion
//
//  Created for Milestone 1 Feature #4: Unified Connection State Machine.
//

import Foundation
import Combine
import os.log

/// 遥控器工作模式（定义于 PROJECT.md Interface Contracts）
public enum HSBRemoteMode: Equatable, Sendable {
    case dual           // 双模协同 (默认: 前台大屏高精控制 + 后台系统兜底)
    case screenOnly     // 仅 hsbtvbrowser 专有大屏通道 (端口 56789 JSON)
    case nativeOnly     // 仅 Apple TV 原生系统遥控通道 (端口 49152/7000)
}

/// 统一连接状态机状态（严格符合 PROJECT.md 契约）
public enum HSBConnectionState: Equatable, CustomStringConvertible, Sendable {
    case disconnected
    case scanning
    case connecting(deviceName: String, mode: HSBRemoteMode)
    case pairing(deviceName: String, pinNeeded: Bool)
    case ready(deviceName: String, mode: HSBRemoteMode)
    case failed(error: String)
    
    public var description: String {
        switch self {
        case .disconnected:
            return "disconnected"
        case .scanning:
            return "scanning"
        case .connecting(let name, let mode):
            return "connecting(device: \(name), mode: \(mode))"
        case .pairing(let name, let pinNeeded):
            return "pairing(device: \(name), pinNeeded: \(pinNeeded))"
        case .ready(let name, let mode):
            return "ready(device: \(name), mode: \(mode))"
        case .failed(let error):
            return "failed(error: \(error))"
        }
    }
    
    /// 状态类别标识（用于转移合法性校验）
    public var category: StateCategory {
        switch self {
        case .disconnected: return .disconnected
        case .scanning:     return .scanning
        case .connecting:   return .connecting
        case .pairing:      return .pairing
        case .ready:        return .ready
        case .failed:       return .failed
        }
    }
    
    public enum StateCategory: String, Equatable, Sendable {
        case disconnected
        case scanning
        case connecting
        case pairing
        case ready
        case failed
    }
}

/// 状态机驱动事件集合
public enum HSBConnectionEvent: Sendable {
    // 用户主动发起的意图事件
    case startScanning
    case stopScanning
    case requestConnect(deviceName: String, mode: HSBRemoteMode)
    case requestDisconnect(reason: String)
    case submitPin(code: String)
    
    // 网络与协议层反馈事件
    case socketConnected(deviceName: String, mode: HSBRemoteMode)
    case pairingRequired(pinNeeded: Bool)
    case pairingSucceeded
    case handshakeFailed(error: String)
    case connectionLost(error: String)
    
    // 超时与生命周期事件
    case connectionTimeout
    case pairingTimeout
    case retryRequested
}

/// 状态机代理协议（定义于 PROJECT.md 契约）
public protocol HSBConnectionStateMachineDelegate: AnyObject {
    /// 状态机完成状态转移后的通知（100% 保证在主线程派发）
    func stateMachine(_ sm: HSBConnectionStateMachine, didTransitionTo state: HSBConnectionState)
    /// 发生非法状态转移被拦截时的告警
    func stateMachine(_ sm: HSBConnectionStateMachine, didRejectTransitionFrom current: HSBConnectionState, to target: HSBConnectionState, reason: String)
}

public extension HSBConnectionStateMachineDelegate {
    func stateMachine(_ sm: HSBConnectionStateMachine, didRejectTransitionFrom current: HSBConnectionState, to target: HSBConnectionState, reason: String) {}
}

/// 统一连接状态机
/// 严格管理 6 大核心连接状态转移矩阵，串行队列并发隔离，主线程派发 UI 回调
public final class HSBConnectionStateMachine: ObservableObject {
    
    private static let logger = Logger(subsystem: "com.never88gone.thlbrowserios", category: "StateMachine")
    
    // MARK: - Published State (Main Thread Only)
    @Published public private(set) var currentState: HSBConnectionState = .disconnected
    
    // MARK: - Delegate
    public weak var delegate: HSBConnectionStateMachineDelegate?
    
    // MARK: - Thread Safety & Isolation
    // 专用串行调度队列，彻底隔离状态读写与转移，消除死锁与数据竞争
    private let stateQueue = DispatchQueue(label: "com.never88gone.thlbrowserios.statemachine.queue", qos: .userInteractive)
    
    // 内部真实状态备份（在 stateQueue 中保持同步）
    private var internalState: HSBConnectionState = .disconnected
    
    // 状态转移历史审计记录（最近 50 条）
    private var transitionHistory: [String] = []
    private let maxHistoryCount = 50
    
    // MARK: - Initialization
    public init(initialState: HSBConnectionState = .disconnected) {
        self.currentState = initialState
        self.internalState = initialState
    }
    
    // MARK: - Synchronous Safe State Access
    public var state: HSBConnectionState {
        return stateQueue.sync { self.internalState }
    }
    
    // MARK: - State Transition Engine
    
    /// 发送驱动事件，自动进行转移合法性校验并执行状态跃迁
    public func handle(event: HSBConnectionEvent) {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            let current = self.internalState
            
            switch (current, event) {
            // 1. disconnected 状态下的事件响应
            case (.disconnected, .startScanning):
                self.transition(to: .scanning)
            case (.disconnected, .requestConnect(let name, let mode)):
                self.transition(to: .connecting(deviceName: name, mode: mode))
            case (.disconnected, .requestDisconnect):
                break
                
            // 2. scanning 状态下的事件响应
            case (.scanning, .stopScanning):
                self.transition(to: .disconnected)
            case (.scanning, .requestConnect(let name, let mode)):
                self.transition(to: .connecting(deviceName: name, mode: mode))
            case (.scanning, .handshakeFailed(let err)):
                self.transition(to: .failed(error: err))
                
            // 3. connecting 状态下的事件响应
            case (.connecting(let name, let mode), .socketConnected):
                self.transition(to: .ready(deviceName: name, mode: mode))
            case (.connecting(let name, _), .pairingRequired(let pinNeeded)):
                self.transition(to: .pairing(deviceName: name, pinNeeded: pinNeeded))
            case (.connecting, .handshakeFailed(let err)):
                self.transition(to: .failed(error: err))
            case (.connecting, .connectionTimeout):
                self.transition(to: .failed(error: "Connection timed out"))
            case (.connecting, .requestDisconnect):
                self.transition(to: .disconnected)
                
            // 4. pairing 状态下的事件响应
            case (.pairing(let name, _), .pairingSucceeded):
                self.transition(to: .ready(deviceName: name, mode: .nativeOnly))
            case (.pairing, .handshakeFailed(let err)):
                self.transition(to: .failed(error: err))
            case (.pairing, .pairingTimeout):
                self.transition(to: .failed(error: "Pairing timed out"))
            case (.pairing, .requestDisconnect):
                self.transition(to: .disconnected)
                
            // 5. ready 状态下的事件响应
            case (.ready, .requestDisconnect):
                self.transition(to: .disconnected)
            case (.ready, .connectionLost(let err)):
                self.transition(to: .failed(error: err))
                
            // 6. failed 状态下的事件响应
            case (.failed, .retryRequested):
                self.transition(to: .scanning)
            case (.failed, .requestConnect(let name, let mode)):
                self.transition(to: .connecting(deviceName: name, mode: mode))
            case (.failed, .requestDisconnect):
                self.transition(to: .disconnected)
            case (.failed, .startScanning):
                self.transition(to: .scanning)
                
            // 未覆盖的非法事件转移
            default:
                self.recordRejection(current: current, event: event)
            }
        }
    }
    
    /// 底层状态转移核心方法（包含合法性校验守卫）
    private func transition(to target: HSBConnectionState) {
        guard isValidTransition(from: internalState, to: target) else {
            recordIllegalTransition(from: internalState, to: target)
            return
        }
        
        let oldState = internalState
        internalState = target
        
        // 记录审计历史
        let record = "[\(ISO8601DateFormatter().string(from: Date()))] \(oldState) -> \(target)"
        transitionHistory.append(record)
        if transitionHistory.count > maxHistoryCount {
            transitionHistory.removeFirst()
        }
        
        Self.logger.info("[State Transition] \(oldState.description) ==> \(target.description)")
        
        // 100% 确保 UI 回调派发在主线程
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentState = target
            self.delegate?.stateMachine(self, didTransitionTo: target)
        }
    }
    
    // MARK: - Legal Transition Matrix Enforcement
    
    private func isValidTransition(from current: HSBConnectionState, to target: HSBConnectionState) -> Bool {
        let fromCat = current.category
        let toCat = target.category
        
        // 允许原地更新相同分类（如更新错误信息、更新连接中设备名）
        if fromCat == toCat {
            return true
        }
        
        switch fromCat {
        case .disconnected:
            return toCat == .scanning || toCat == .connecting
            
        case .scanning:
            return toCat == .disconnected || toCat == .connecting || toCat == .failed
            
        case .connecting:
            return toCat == .disconnected || toCat == .pairing || toCat == .ready || toCat == .failed
            
        case .pairing:
            return toCat == .disconnected || toCat == .ready || toCat == .failed
            
        case .ready:
            return toCat == .disconnected || toCat == .connecting || toCat == .failed
            
        case .failed:
            return toCat == .disconnected || toCat == .scanning || toCat == .connecting
        }
    }
    
    private func recordIllegalTransition(from current: HSBConnectionState, to target: HSBConnectionState) {
        let reason = "Illegal state transition attempted from \(current) to \(target)"
        Self.logger.error("[StateMachine Rejected] \(reason)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.stateMachine(self, didRejectTransitionFrom: current, to: target, reason: reason)
        }
    }
    
    private func recordRejection(current: HSBConnectionState, event: HSBConnectionEvent) {
        Self.logger.warning("[StateMachine Ignored] No transition defined for state: \(current) on event: \(String(describing: event))")
    }
    
    // MARK: - Diagnostics
    public func getAuditHistory() -> [String] {
        return stateQueue.sync { self.transitionHistory }
    }
}
