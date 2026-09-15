//
//  HSBReconnectionPolicy.swift
//  HSBWatchCompanion
//
//  Created for Milestone 1 Feature #4: Equal Jitter Exponential Backoff Reconnection Policy.
//

import Foundation
import Network
import os.log

/// 工业级 Equal Jitter 指数退避重连策略引擎
/// 避免多端重试风暴（Thundering Herd Problem），提供稳定连接复位与意图守卫
public final class HSBReconnectionPolicy {
    
    private static let logger = Logger(subsystem: "com.never88gone.thlbrowserios", category: "Reconnection")
    
    // MARK: - Configuration
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffMultiplier: Double
    public let maxRetryAttempts: Int
    public let stabilityThreshold: TimeInterval // 稳定连接时间阈值 (秒)
    
    // MARK: - State
    private var _currentRetryCount: Int = 0

    /// 公开的当前重试计数，通过内部串行队列同步安全读取，彻底杜绝多线程 Data Race
    public var currentRetryCount: Int {
        return queue.sync { self._currentRetryCount }
    }

    private var isManualDisconnect: Bool = false
    private var scheduledTimer: DispatchSourceTimer?
    private var stabilityTimer: DispatchSourceTimer?
    
    private let queue = DispatchQueue(label: "com.never88gone.thlbrowserios.reconnect.queue", qos: .utility)
    
    // MARK: - Initialization
    public init(
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0,
        maxRetryAttempts: Int = 5,
        stabilityThreshold: TimeInterval = 10.0
    ) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
        self.maxRetryAttempts = maxRetryAttempts
        self.stabilityThreshold = stabilityThreshold
    }
    
    deinit {
        internalCancelAllTimers()
    }
    
    // MARK: - Intent API
    
    /// 标记用户主动断开，彻底抑制自动重连
    public func markManualDisconnect() {
        queue.async {
            self.isManualDisconnect = true
            self.internalCancelAllTimers()
            self._currentRetryCount = 0
            Self.logger.info("Manual disconnect marked. Auto-reconnection suppressed.")
        }
    }
    
    /// 连接建立成功时通知
    /// - Parameter onStable: 当连接稳定持续超过 stabilityThreshold 秒未掉线时的回调
    public func notifyConnected(onStable: @escaping () -> Void = {}) {
        queue.async {
            self.isManualDisconnect = false
            self.cancelScheduledRetry()
            
            // 启动稳定性计时器，若超过阈值未掉线，重置重试计数
            self.stabilityTimer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + self.stabilityThreshold)
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                self._currentRetryCount = 0
                Self.logger.info("Connection stable for \(self.stabilityThreshold)s. Resetting retry counter.")
                self.stabilityTimer = nil
                DispatchQueue.global().async {
                    onStable()
                }
            }
            timer.resume()
            self.stabilityTimer = timer
        }
    }
    
    /// 发生非预期掉线时，调度重试任务
    /// - Parameter action: 到达退避延时后的重连动作
    /// - Returns: 是否被调度（若已达最大次数或主动断开，返回 false）
    public func scheduleReconnectIfEligible(action: @escaping (_ attempt: Int, _ delay: TimeInterval) -> Void) -> Bool {
        return queue.sync {
            if self.isManualDisconnect {
                Self.logger.info("Drop ignored: Manual disconnect in progress.")
                return false
            }
            
            self.stabilityTimer?.cancel()
            self.stabilityTimer = nil
            
            if self._currentRetryCount >= self.maxRetryAttempts {
                Self.logger.warning("Max retry limit (\(self.maxRetryAttempts)) reached. Ceasing auto-reconnect.")
                return false
            }
            
            let delay = self.computeEqualJitterDelay(for: self._currentRetryCount)
            self._currentRetryCount += 1
            let attemptToReport = self._currentRetryCount
            
            Self.logger.info("Scheduling reconnect attempt #\(attemptToReport) in \(String(format: "%.2f", delay))s")
            
            self.scheduledTimer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + delay)
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.scheduledTimer = nil
                DispatchQueue.global().async {
                    action(attemptToReport, delay)
                }
            }
            timer.resume()
            self.scheduledTimer = timer
            
            return true
        }
    }
    
    /// 局域网网络恢复时，立即无延迟触发一次尝试
    public func immediateRetryOnNetworkRestored(action: @escaping () -> Void) {
        queue.async {
            guard !self.isManualDisconnect else { return }
            Self.logger.info("Network path restored! Triggering immediate reconnect...")
            self.cancelScheduledRetry()
            DispatchQueue.global().async {
                action()
            }
        }
    }
    
    /// 取消所有进行中的计时器
    public func cancelAllTimers() {
        queue.sync {
            self.internalCancelAllTimers()
        }
    }
    
    private func internalCancelAllTimers() {
        scheduledTimer?.cancel()
        scheduledTimer = nil
        stabilityTimer?.cancel()
        stabilityTimer = nil
    }
    
    private func cancelScheduledRetry() {
        scheduledTimer?.cancel()
        scheduledTimer = nil
    }
    
    // MARK: - Backoff Mathematics (Equal Jitter)
    
    private func computeEqualJitterDelay(for attempt: Int) -> TimeInterval {
        // T_cap = min(maxDelay, baseDelay * (multiplier ^ attempt))
        let exponential = self.baseDelay * pow(self.backoffMultiplier, Double(attempt))
        let cap = min(self.maxDelay, exponential)
        
        // Equal Jitter: Half base + Uniform(0, Half base)
        let half = cap / 2.0
        let jitter = Double.random(in: 0.0...half)
        return half + jitter
    }
}
