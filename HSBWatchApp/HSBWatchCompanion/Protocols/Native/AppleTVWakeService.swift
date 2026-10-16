//
//  AppleTVWakeService.swift
//  HSBWatchCompanion
//

import Foundation
import Network

public final class AppleTVWakeService {
    private static let knockPorts: [UInt16] = [3689, 7000, 49152, 49153]
    
    public static func wakeDevice(host: String, targetDeviceName: String?, completion: ((Bool) -> Void)? = nil) {
        let group = DispatchGroup()
        var atLeastOneSucceeded = false
        let lock = NSLock()
        let bgQueue = DispatchQueue(label: "com.tanghulu.native.wake.queue", qos: .userInitiated)
        
        for port in knockPorts {
            group.enter()
            let endpoint = nw_endpoint_create_host(host, "\(port)")
            let params = nw_parameters_create()
            let conn = nw_connection_create(endpoint, params)
            nw_connection_set_queue(conn, bgQueue)
            
            var didFinish = false
            let finish = { (success: Bool) in
                if !didFinish {
                    didFinish = true
                    if success {
                        lock.lock()
                        atLeastOneSucceeded = true
                        lock.unlock()
                    }
                    nw_connection_cancel(conn)
                    group.leave()
                }
            }
            
            nw_connection_set_state_changed_handler(conn) { state, _ in
                if state == nw_connection_state_ready {
                    finish(true)
                } else if state == nw_connection_state_failed || state == nw_connection_state_cancelled {
                    finish(false)
                }
            }
            
            nw_connection_start(conn)
            bgQueue.asyncAfter(deadline: .now() + 0.5) {
                finish(false)
            }
        }
        
        // 若已知 MAC 地址，亦可辅以 WoL 广播唤醒
        let targetDevID = targetDeviceName ?? "Apple TV"
        if let mac = MACStore.load(for: targetDevID) {
            try? WakeOnLAN.send(mac: mac, targetIP: host)
        }
        
        group.notify(queue: .main) {
            completion?(atLeastOneSucceeded)
        }
    }
}
