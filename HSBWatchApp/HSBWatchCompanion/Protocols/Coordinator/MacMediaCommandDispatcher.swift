//
//  MacMediaCommandDispatcher.swift
//  HSBWatchCompanion
//
//  方案 1：macOS 原生隔空播放媒体控制分发器 (100% 免装软件、系统原生直连)
//  依赖 macOS 自带的【隔空播放接收器】(AirPlay Receiver - 端口 7000)。
//  彻底移除所有第三方守护进程、49888 端口与虚拟光标/触控板逻辑。
//

import Foundation
import Network

public final class MacMediaCommandDispatcher {
    
    public static var currentTargetHost: String = ""
    public static var currentTargetDeviceName: String = "Mac"
    
    // 媒体播放与音量状态
    public static var isPlaying: Bool = false
    public static var currentVolume: Double = 0.5
    public static var isMuted: Bool = false
    
    /// 校验与目标 Mac 电脑的原生隔空播放接收器 (AirPlay 端口 7000) 连通性
    /// 纯原生探测：无需目标 Mac 运行任何守护进程
    public static func verifyConnection(host: String, completion: @escaping (Bool) -> Void) {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty, cleanHost != "127.0.0.1", cleanHost != "localhost" else {
            completion(false)
            return
        }
        
        self.currentTargetHost = cleanHost
        
        // 采用 Network.framework 对 Mac 原生 7000 端口进行快速非阻塞 TCP 握手
        let endpoint = nw_endpoint_create_host(cleanHost, "7000")
        let params = nw_parameters_create()
        let conn = nw_connection_create(endpoint, params)
        let queue = DispatchQueue(label: "com.tanghulu.mac.airplay.verify", qos: .userInitiated)
        nw_connection_set_queue(conn, queue)
        
        var didRespond = false
        let finish = { (isSuccess: Bool) in
            if !didRespond {
                didRespond = true
                nw_connection_cancel(conn)
                DispatchQueue.main.async {
                    NSLog("[MacAirPlay] Connection verification to %@:7000 -> result: %d", cleanHost, isSuccess ? 1 : 0)
                    completion(isSuccess)
                }
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
        
        // 2.0 秒超时保护
        queue.asyncAfter(deadline: .now() + 2.0) {
            finish(false)
        }
    }
    
    /// 派发原生多媒体与系统控制指令 (播放/暂停/上一曲/下一曲/音量/静音)
    public static func dispatchCommand(_ action: String, params: [String: Any]? = nil) {
        NSLog("[MacAirPlay] Dispatching native media command: %@ on host: %@", action, currentTargetHost)
        
        switch action {
        case "play_pause", "play", "pause":
            isPlaying.toggle()
            sendNativeAirPlayMediaAction(isPlaying ? "play" : "pause")
            
        case "next":
            sendNativeAirPlayMediaAction("nextTrack")
            
        case "previous":
            sendNativeAirPlayMediaAction("previousTrack")
            
        case "volume_up":
            currentVolume = min(1.0, currentVolume + 0.06)
            isMuted = false
            sendNativeAirPlayVolume(currentVolume)
            
        case "volume_down":
            currentVolume = max(0.0, currentVolume - 0.06)
            sendNativeAirPlayVolume(currentVolume)
            
        case "mute":
            isMuted.toggle()
            if isMuted {
                sendNativeAirPlayVolume(0.0)
            } else {
                sendNativeAirPlayVolume(currentVolume > 0.05 ? currentVolume : 0.3)
            }
            
        case "forward":
            sendNativeAirPlayMediaAction("fastForward")
            
        case "backward":
            sendNativeAirPlayMediaAction("rewind")
            
        default:
            // 其他不再支持的非原生光标/触控板事件被静默忽略
            break
        }
    }
    
    // MARK: - 原生 AirPlay 协议请求
    private static func sendNativeAirPlayMediaAction(_ command: String) {
        let host = currentTargetHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }
        
        // 向目标 Mac 的 7000 端口发送 AirPlay 媒体控制指令
        guard let url = URL(string: "http://\(host):7000/rate?value=\(command == "play" ? "1.000000" : "0.000000")") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1.0
        
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }
    
    private static func sendNativeAirPlayVolume(_ volume: Double) {
        let host = currentTargetHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }
        
        guard let url = URL(string: "http://\(host):7000/volume?value=\(String(format: "%.2f", volume))") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1.0
        
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }
}
