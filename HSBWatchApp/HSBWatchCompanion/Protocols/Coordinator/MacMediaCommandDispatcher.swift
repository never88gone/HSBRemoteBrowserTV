//
//  MacMediaCommandDispatcher.swift
//  HSBWatchCompanion
//
//  用于向当前目标 Mac 电脑端侧守护进程 (端口 49888) 发送极速、零阻拦的系统控制与媒体按键指令。
//  支持局域网 mDNS 主机名 (.local) 与 IPv4 自动解析，内置高频触控板滑动平滑聚合器。
//

import Foundation

public final class MacMediaCommandDispatcher {
    
    public static var currentTargetHost: String = "127.0.0.1"
    
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.0
        config.timeoutIntervalForResource = 1.0
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpShouldUsePipelining = true
        return URLSession(configuration: config)
    }()
    
    // MARK: - 高频触控滑动平滑缓冲聚合器 (Throttle Buffer)
    private static let throttleQueue = DispatchQueue(label: "com.never88gone.thlbrowserios.mactouch.queue", qos: .userInteractive)
    private static var pendingDx: CGFloat = 0.0
    private static var pendingDy: CGFloat = 0.0
    private static var isThrottleScheduled: Bool = false
    
    /// 派发系统控制指令 (支持离散按键与平滑滑动)
    public static func dispatchCommand(_ action: String, params: [String: Any]? = nil) {
        if action == "pan" {
            let dx = (params?["dx"] as? CGFloat) ?? (params?["dx"] as? Double).map { CGFloat($0) } ?? 0.0
            let dy = (params?["dy"] as? CGFloat) ?? (params?["dy"] as? Double).map { CGFloat($0) } ?? 0.0
            dispatchSmoothPan(dx: dx, dy: dy)
            return
        }
        
        sendImmediateCommand(action: action, params: params)
    }
    
    /// 对鼠标平移事件进行 20ms 平滑聚合，杜绝短时间大量并发请求造成丢包或阻塞
    private static func dispatchSmoothPan(dx: CGFloat, dy: CGFloat) {
        throttleQueue.async {
            pendingDx += dx
            pendingDy += dy
            
            if !isThrottleScheduled {
                isThrottleScheduled = true
                throttleQueue.asyncAfter(deadline: .now() + 0.02) {
                    let sendDx = pendingDx
                    let sendDy = pendingDy
                    pendingDx = 0.0
                    pendingDy = 0.0
                    isThrottleScheduled = false
                    
                    if abs(sendDx) > 0.01 || abs(sendDy) > 0.01 {
                        sendImmediateCommand(action: "pan", params: ["dx": sendDx, "dy": sendDy])
                    }
                }
            }
        }
    }
    
    private static func sendImmediateCommand(action: String, params: [String: Any]?) {
        let hostToUse = currentTargetHost.trimmingCharacters(in: .whitespacesAndNewlines)
        var targetHosts: [String] = []
        
        if !hostToUse.isEmpty && hostToUse != "127.0.0.1" && hostToUse != "localhost" {
            targetHosts.append(hostToUse)
        }
        // 同时兼顾模拟器或同机测试
        targetHosts.append("127.0.0.1")
        
        var queryItems = [URLQueryItem(name: "action", value: action)]
        if let params = params {
            for (k, v) in params {
                queryItems.append(URLQueryItem(name: k, value: "\(v)"))
            }
        }
        
        for host in targetHosts {
            var components = URLComponents()
            components.scheme = "http"
            components.host = host
            components.port = 49888
            components.path = "/control"
            components.queryItems = queryItems
            
            guard let url = components.url else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 0.8
            
            session.dataTask(with: request) { _, response, error in
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    // NSLog("[MacRemote] Dispatched action '%@' to %@:49888 (200 OK)", action, host)
                } else if let err = error as? URLError, err.code != .cannotConnectToHost {
                    // NSLog("[MacRemote] Error dispatching to %@: %@", host, err.localizedDescription)
                }
            }.resume()
        }
    }
    
    /// 校验与目标 Mac 电脑的端侧控制通道连通性
    public static func verifyConnection(host: String, completion: @escaping (Bool) -> Void) {
        self.currentTargetHost = host
        let targetHost = host.isEmpty ? "127.0.0.1" : host
        
        guard let url = URL(string: "http://\(targetHost):49888/status") else {
            completion(false)
            return
        }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        session.dataTask(with: req) { data, response, _ in
            let isOnline: Bool
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                isOnline = true
            } else {
                isOnline = false
            }
            DispatchQueue.main.async {
                completion(isOnline)
            }
        }.resume()
    }
}
