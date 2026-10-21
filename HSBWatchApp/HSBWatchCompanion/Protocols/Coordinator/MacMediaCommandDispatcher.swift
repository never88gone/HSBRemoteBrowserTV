//
//  MacMediaCommandDispatcher.swift
//  HSBWatchCompanion
//
//  用于向当前目标 Mac 电脑端侧守护进程 (端口 49888) 发送极速、零阻拦的系统控制与媒体按键指令。
//  采用原生 BSD Socket，彻底规避 ATS 拦截与 URLSession 延迟，实现毫秒级物理级响应。
//

import Foundation
import Darwin

public final class MacMediaCommandDispatcher {
    
    public static var currentTargetHost: String = "127.0.0.1"
    
    private static let _setupOnce: Void = {
        signal(SIGPIPE, SIG_IGN)
    }()
    
    public static func dispatchCommand(_ action: String, params: [String: Any]? = nil) {
        _ = _setupOnce
        let hostToUse = currentTargetHost.isEmpty ? "127.0.0.1" : currentTargetHost
        
        DispatchQueue.global(qos: .userInteractive).async {
            var path = "/control?action=\(action)"
            if let params = params {
                for (k, v) in params {
                    if let strVal = "\(v)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                        path += "&\(k)=\(strVal)"
                    }
                }
            }
            
            // 向 127.0.0.1 及局域网目标直发指令
            var targetIPs = ["127.0.0.1"]
            if hostToUse != "127.0.0.1" && hostToUse != "localhost" && !hostToUse.isEmpty {
                targetIPs.append(hostToUse)
            }
            
            for ip in targetIPs {
                sendRawHTTPRequest(ip: ip, port: 49888, path: path, action: action)
            }
        }
    }
    
    private static func sendRawHTTPRequest(ip: String, port: UInt16, path: String, action: String) {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            NSLog("[MacRemote] Failed to create socket")
            return
        }
        defer { Darwin.close(sock) }
        
        // 关键防御：禁用 SIGPIPE 信号，防止对端断开导致的进程崩溃
        var nosigpipe: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(ip)
        
        var tv = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        let connectRes = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.connect(sock, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if connectRes == 0 {
            let request = "GET \(path) HTTP/1.0\r\nHost: \(ip):\(port)\r\nConnection: close\r\n\r\n"
            _ = request.withCString { Darwin.send(sock, $0, strlen($0), 0) }
            NSLog("[MacRemote] Success dispatched action '%@' to %@:%u via raw socket", action, ip, port)
        } else {
            NSLog("[MacRemote] Connect to %@:%u failed (errno: %d)", ip, port, errno)
        }
    }
    
    public static func verifyConnection(host: String, completion: @escaping (Bool) -> Void) {
        _ = _setupOnce
        self.currentTargetHost = host
        DispatchQueue.global(qos: .userInitiated).async {
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            guard sock >= 0 else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            defer { Darwin.close(sock) }
            
            var nosigpipe: Int32 = 1
            setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout<Int32>.size))
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = UInt16(49888).bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            
            var tv = timeval(tv_sec: 1, tv_usec: 0)
            setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
            
            let connectRes = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.connect(sock, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            let isOnline = (connectRes == 0)
            DispatchQueue.main.async {
                completion(isOnline)
            }
        }
    }
}
