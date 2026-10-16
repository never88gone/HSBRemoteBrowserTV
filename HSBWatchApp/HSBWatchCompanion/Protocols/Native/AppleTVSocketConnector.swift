//
//  AppleTVSocketConnector.swift
//  HSBWatchCompanion
//

import Foundation
import Network

public enum AppleTVSocketError: LocalizedError {
    case invalidHost(String)
    case connectionFailed(errno: Int32)
    
    public var errorDescription: String? {
        switch self {
        case .invalidHost(let host):
            return "无效主机地址: \(host)"
        case .connectionFailed(let errno):
            return "Native TCP 连接失败 (errno: \(errno))"
        }
    }
}

public final class AppleTVSocketConnector {
    
    public static func connectToHost(host: String, candidatePorts: [UInt16]) async throws -> (fd: Int32, connectedPort: UInt16) {
        NSLog("[ATV_CONNECT] Resolving host: %@", host)
        var inAddr = in_addr()
        var resolved = (host.withCString { inet_pton(AF_INET, $0, &inAddr) } == 1)
        if !resolved {
            var hints = addrinfo()
            hints.ai_family = AF_INET
            hints.ai_socktype = SOCK_STREAM
            var res: UnsafeMutablePointer<addrinfo>?
            if getaddrinfo(host, nil, &hints, &res) == 0, let first = res {
                let sin = first.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                inAddr = sin.sin_addr
                resolved = true
                freeaddrinfo(res)
            }
        }
        guard resolved else {
            NSLog("[ATV_CONNECT] Failed to resolve host: %@", host)
            throw AppleTVSocketError.invalidHost(host)
        }
        
        var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var copyAddr = inAddr
        inet_ntop(AF_INET, &copyAddr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
        let resolvedIP = String(cString: ipBuf)
        NSLog("[ATV_CONNECT] Host %@ resolved to %@", host, resolvedIP)
        
        var fd: Int32 = -1
        var connectedPort: UInt16 = 0
        var lastErrno: Int32 = 0
        
        for candidatePort in candidatePorts {
            NSLog("[ATV_CONNECT] Attempting TCP connect to %@:%u ...", resolvedIP, candidatePort)
            var addr = sockaddr_in()
            addr.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port   = in_port_t(candidatePort).bigEndian
            addr.sin_addr   = inAddr
            
            let trialFD = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            guard trialFD >= 0 else {
                lastErrno = errno
                continue
            }
            
            #if os(macOS)
            PrimaryInterface.bindSourceAddress(fd: trialFD, logHost: host)
            #endif
            
            let flags = fcntl(trialFD, F_GETFL, 0)
            _ = fcntl(trialFD, F_SETFL, flags | O_NONBLOCK)
            
            let rc = withUnsafePointer(to: addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(trialFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            if rc == 0 {
                fd = trialFD
                connectedPort = candidatePort
            } else if errno == EINPROGRESS {
                var pfd = pollfd(fd: trialFD, events: Int16(POLLOUT), revents: 0)
                let ready = poll(&pfd, 1, 3000)
                if ready > 0 {
                    var err: Int32 = 0
                    var len = socklen_t(MemoryLayout<Int32>.size)
                    getsockopt(trialFD, SOL_SOCKET, SO_ERROR, &err, &len)
                    if err == 0 {
                        fd = trialFD
                        connectedPort = candidatePort
                    } else {
                        lastErrno = err
                    }
                } else {
                    lastErrno = ETIMEDOUT
                }
            } else {
                lastErrno = errno
            }
            
            if fd >= 0 {
                let currentFlags = fcntl(fd, F_GETFL, 0)
                _ = fcntl(fd, F_SETFL, currentFlags & ~O_NONBLOCK)
                NSLog("[ATV_CONNECT] Successfully connected to %@:%u (fd=%d)", resolvedIP, connectedPort, fd)
                break
            } else {
                NSLog("[ATV_CONNECT] Failed connect to %@:%u (errno: %d - %s)", resolvedIP, candidatePort, lastErrno, strerror(lastErrno))
                Darwin.close(trialFD)
            }
        }
        
        guard fd >= 0 else {
            NSLog("[ATV_CONNECT] All candidate ports failed for %@, lastErrno=%d", resolvedIP, lastErrno)
            throw AppleTVSocketError.connectionFailed(errno: lastErrno)
        }
        
        var enable: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &enable, socklen_t(MemoryLayout<Int32>.size))
        var idleSec: Int32 = 10
        setsockopt(fd, IPPROTO_TCP, TCP_KEEPALIVE, &idleSec, socklen_t(MemoryLayout<Int32>.size))
        
        return (fd, connectedPort)
    }
}
