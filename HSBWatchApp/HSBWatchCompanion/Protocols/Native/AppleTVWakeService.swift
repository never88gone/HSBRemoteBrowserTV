//
//  AppleTVWakeService.swift
//  HSBWatchCompanion
//

import Foundation
import Network

public final class AppleTVWakeService {
    private static let knockPorts: [UInt16] = [3689, 7000, 49152, 49153]
    
    /// 唤醒 Apple TV：多路径并发唤醒（WoL 局域网广播 + 多端口持续 TCP 敲门唤醒）
    public static func wakeDevice(host: String, targetDeviceName: String?, completion: ((Bool) -> Void)? = nil) {
        let bgQueue = DispatchQueue(label: "com.tanghulu.native.wake.queue", qos: .userInitiated)
        
        bgQueue.async {
            let targetDevID = targetDeviceName ?? "Apple TV"
            
            // 1. 尝试 WoL 魔法包（如果有保存的 MAC）
            if let mac = MACStore.load(for: targetDevID) {
                NSLog("[AppleTVWakeService] Sending initial WoL to MAC %@ at %@", mac, host)
                try? WakeOnLAN.send(mac: mac, targetIP: host)
            }
            
            // 2. 启动多轮渐进式 TCP 端口敲门探测（持续约 4~5 秒，最多 4 轮，每轮 1 秒）
            var isWoken = false
            let maxAttempts = 4
            
            for attempt in 0..<maxAttempts {
                if isWoken { break }
                
                let attemptGroup = DispatchGroup()
                var attemptSuccess = false
                let attemptLock = NSLock()
                
                for port in knockPorts {
                    attemptGroup.enter()
                    HSBAppleTVDiscovery.probeTCPConnection(host: host, port: port, timeout: 0.9) { success in
                        if success {
                            attemptLock.lock()
                            attemptSuccess = true
                            attemptLock.unlock()
                        }
                        attemptGroup.leave()
                    }
                }
                
                // 等待当前轮次完成（最多 1.0 秒）
                _ = attemptGroup.wait(timeout: .now() + 1.0)
                
                if attemptSuccess {
                    NSLog("[AppleTVWakeService] Apple TV responded on knock attempt %d! Host is awake.", attempt + 1)
                    isWoken = true
                    break
                }
                
                // 若仍未响应，且已知 MAC，重发一次 WoL
                if let mac = MACStore.load(for: targetDevID) {
                    try? WakeOnLAN.send(mac: mac, targetIP: host)
                }
                
                // 轮次间缓冲
                Thread.sleep(forTimeInterval: 0.15)
            }
            
            DispatchQueue.main.async {
                NSLog("[AppleTVWakeService] Wake sequence finished. isWoken = %d", isWoken ? 1 : 0)
                completion?(isWoken)
            }
        }
    }
}
