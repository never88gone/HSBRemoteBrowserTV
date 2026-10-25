//
//  MacMediaCommandDispatcher.swift
//  HSBWatchCompanion
//
//  用于向当前目标 Mac 电脑端侧守护进程 (端口 49888) 发送极速、零阻拦的系统控制与媒体按键指令。
//  支持局域网 mDNS 主机名 (.local) 与 IPv4 自动解析。
//  内置高精度人体工学加速度曲线 (Ballistics Acceleration) 与单飞行背压管道 (In-Flight Backpressure Pipeline)。
//

import Foundation
import CoreGraphics

public final class MacMediaCommandDispatcher {
    
    public static var currentTargetHost: String = "127.0.0.1"
    
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.5
        config.timeoutIntervalForResource = 0.5
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpShouldUsePipelining = true
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()
    
    // MARK: - 高精度串行背压管道队列 (消除网络乱序与并发 Race Condition)
    private static let throttleQueue = DispatchQueue(label: "com.never88gone.thlbrowserios.mactouch.queue", qos: .userInteractive)
    
    // 鼠标位移状态
    private static var pendingDx: CGFloat = 0.0
    private static var pendingDy: CGFloat = 0.0
    private static var isPanInFlight: Bool = false
    
    // 页面无级滚轮状态
    private static var pendingScrollDx: CGFloat = 0.0
    private static var pendingScrollDy: CGFloat = 0.0
    private static var isScrollInFlight: Bool = false
    
    // MARK: - 人体工程学非线性动态加速度算法 (Ballistics Curve)
    /// 微动慢速（< 1.5pt）保持像素级精准微操不飘，快速大幅划动平滑提升至 4.5x 一甩即达全屏
    public static func calculateBallistics(dx: CGFloat, dy: CGFloat) -> (CGFloat, CGFloat) {
        let dist = hypot(dx, dy)
        guard dist > 0.001 else { return (0, 0) }
        
        let factor: CGFloat
        if dist < 1.5 {
            // 极微动慢速：0.95x 稳定微调
            factor = 0.95
        } else if dist < 5.0 {
            // 慢速常态移动：0.95x ~ 1.5x
            factor = 0.95 + (dist - 1.5) * 0.16
        } else if dist < 14.0 {
            // 中速正常移动：1.5x ~ 2.8x
            factor = 1.5 + (dist - 5.0) * 0.14
        } else {
            // 快速甩动手腕：最大 4.5x 封顶
            factor = min(4.5, 2.8 + (dist - 14.0) * 0.12)
        }
        
        return (dx * factor, dy * factor)
    }
    
    private static func extractCGFloat(_ dict: [String: Any]?, key: String) -> CGFloat {
        guard let val = dict?[key] else { return 0.0 }
        if let cg = val as? CGFloat { return cg }
        if let d = val as? Double { return CGFloat(d) }
        if let i = val as? Int { return CGFloat(i) }
        if let num = val as? NSNumber { return CGFloat(num.doubleValue) }
        return 0.0
    }

    /// 派发系统控制指令 (支持离散按键与平滑滑动)
    public static func dispatchCommand(_ action: String, params: [String: Any]? = nil) {
        if action == "pan" {
            let dx = extractCGFloat(params, key: "dx")
            let dy = extractCGFloat(params, key: "dy")
            dispatchSmoothPan(dx: dx, dy: dy)
            return
        }
        
        if action == "scroll" {
            let dy = extractCGFloat(params, key: "dy")
            let dx = extractCGFloat(params, key: "dx")
            dispatchSmoothScroll(dx: dx, dy: dy)
            return
        }
        
        sendImmediateCommand(action: action, params: params)
    }
    
    // MARK: - 鼠标滑动背压管道 (保证单飞行请求，消除乱序颠簸)
    private static func dispatchSmoothPan(dx: CGFloat, dy: CGFloat) {
        let (accelDx, accelDy) = calculateBallistics(dx: dx, dy: dy)
        
        throttleQueue.async {
            pendingDx += accelDx
            pendingDy += accelDy
            tryFlushPan()
        }
    }
    
    private static func tryFlushPan() {
        guard !isPanInFlight else { return }
        
        let sendDx = pendingDx
        let sendDy = pendingDy
        
        guard abs(sendDx) > 0.05 || abs(sendDy) > 0.05 else { return }
        
        pendingDx = 0.0
        pendingDy = 0.0
        isPanInFlight = true
        
        sendPanHTTP(dx: sendDx, dy: sendDy) {
            throttleQueue.async {
                isPanInFlight = false
                if abs(pendingDx) > 0.05 || abs(pendingDy) > 0.05 {
                    tryFlushPan()
                }
            }
        }
    }
    
    private static func sendPanHTTP(dx: CGFloat, dy: CGFloat, completion: @escaping () -> Void) {
        guard let url = buildControlURL(action: "pan", params: [
            "dx": String(format: "%.2f", dx),
            "dy": String(format: "%.2f", dy)
        ]) else {
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.5
        
        session.dataTask(with: request) { _, _, _ in
            completion()
        }.resume()
    }
    
    // MARK: - 页面滚轮背压管道
    private static func dispatchSmoothScroll(dx: CGFloat, dy: CGFloat) {
        throttleQueue.async {
            pendingScrollDx += dx
            pendingScrollDy += dy
            tryFlushScroll()
        }
    }
    
    private static func tryFlushScroll() {
        guard !isScrollInFlight else { return }
        
        let sendDx = pendingScrollDx
        let sendDy = pendingScrollDy
        
        guard abs(sendDx) > 0.1 || abs(sendDy) > 0.1 else { return }
        
        pendingScrollDx = 0.0
        pendingScrollDy = 0.0
        isScrollInFlight = true
        
        guard let url = buildControlURL(action: "scroll", params: [
            "dx": String(format: "%.1f", sendDx),
            "dy": String(format: "%.1f", sendDy)
        ]) else {
            isScrollInFlight = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.5
        
        session.dataTask(with: request) { _, _, _ in
            throttleQueue.async {
                isScrollInFlight = false
                if abs(pendingScrollDx) > 0.1 || abs(pendingScrollDy) > 0.1 {
                    tryFlushScroll()
                }
            }
        }.resume()
    }
    
    // MARK: - 离散即时指令发送
    private static func sendImmediateCommand(action: String, params: [String: Any]?) {
        var strParams: [String: String]? = nil
        if let params = params {
            var map = [String: String]()
            for (k, v) in params {
                map[k] = "\(v)"
            }
            strParams = map
        }
        
        guard let url = buildControlURL(action: action, params: strParams) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.8
        
        session.dataTask(with: request) { _, _, _ in }.resume()
    }
    
    private static func buildControlURL(action: String, params: [String: String]?) -> URL? {
        let hostToUse = currentTargetHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = (!hostToUse.isEmpty && hostToUse != "127.0.0.1" && hostToUse != "localhost") ? hostToUse : "127.0.0.1"
        
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = 49888
        components.path = "/control"
        
        var items = [URLQueryItem(name: "action", value: action)]
        if let params = params {
            for (k, v) in params {
                items.append(URLQueryItem(name: k, value: v))
            }
        }
        components.queryItems = items
        return components.url
    }
    
    /// 校验与目标 Mac 电脑的端侧控制通道连通性
    public static func verifyConnection(host: String, completion: @escaping (Bool) -> Void) {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.currentTargetHost = cleanHost
        
        var components = URLComponents()
        components.scheme = "http"
        components.host = cleanHost.isEmpty ? "127.0.0.1" : cleanHost
        components.port = 49888
        components.path = "/status"
        
        guard let url = components.url else {
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
