//
//  HSBAppleTVDiscovery.swift
//  HSBWatchCompanion
//
//  基于 Apple TV 局域网 Bonjour 发现与过滤架构。
//  支持 _companion-link._tcp、_airplay._tcp 与 _thltv._tcp 多通道并发扫描、TXT 记录解析与端口敲门唤醒。
//

import Foundation
import Network
import os.log
import Darwin

private let log = Logger(subsystem: "com.never88gone.thlbrowserios", category: "AppleTVDiscovery")

/// 发现的局域网大屏与 Apple TV 设备模型 (兼容 Objective-C 与 Swift)
@objc public final class HSBDiscoveredAppleTV: NSObject {
    @objc public let id: String
    @objc public let name: String
    @objc public let host: String
    @objc public let port: UInt16
    @objc public let modelName: String?
    @objc public let isNativeAppleTV: Bool
    @objc public let isBrowserApp: Bool
    @objc public let rawEndpoint: nw_endpoint_t?
    
    @objc public init(
        id: String,
        name: String,
        host: String,
        port: UInt16,
        modelName: String?,
        isNativeAppleTV: Bool,
        isBrowserApp: Bool,
        rawEndpoint: nw_endpoint_t? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.modelName = modelName
        self.isNativeAppleTV = isNativeAppleTV
        self.isBrowserApp = isBrowserApp
        self.rawEndpoint = rawEndpoint
        super.init()
    }
    
    @objc public var isDualMode: Bool {
        return isNativeAppleTV && isBrowserApp
    }
    
    @objc public var isAndroidTV: Bool {
        let lowerModel = (modelName ?? "").lowercased()
        let lowerName = name.lowercased()
        return lowerModel.contains("android") || lowerName.contains("android") || (isBrowserApp && !isNativeAppleTV && !isMacDevice)
    }
    
    @objc public var isMacDevice: Bool {
        let lowerModel = (modelName ?? "").lowercased()
        let lowerName = name.lowercased()
        return lowerModel.contains("mac") || lowerName.contains("mac")
    }
    
    @objc public var deviceCategoryIconName: String {
        if isAndroidTV {
            return "tv.and.mediabox"
        }
        if isMacDevice {
            let lower = (modelName ?? "").lowercased()
            if lower.contains("book") {
                return "laptopcomputer"
            }
            return "desktopcomputer"
        }
        return "appletv.fill"
    }
    
    @objc public var displaySubtitle: String {
        if isAndroidTV {
            return "Android TV · 糖葫芦大屏专属遥控就绪"
        }
        if isMacDevice {
            let modelStr = modelName ?? "Mac"
            return "macOS (\(modelStr)) · 原生隔空播放媒体控制"
        }
        if let model = modelName, !model.isEmpty {
            return "Apple TV (\(model)) · 系统原生硬件就绪"
        }
        return "Apple TV · 系统原生硬件就绪"
    }
}

/// 局域网 Apple TV 自动发现引擎 (原生 Bonjour 发现与过滤架构)
@objc public final class HSBAppleTVDiscovery: NSObject {
    @objc public static let shared = HSBAppleTVDiscovery()
    @objc public static let devicesDidChangeNotification = Notification.Name("HSBAppleTVDiscoveryDevicesDidChangeNotification")
    
    private var companionBrowser: NetServiceBrowser?
    private var thlTVBrowser: NetServiceBrowser?
    private var thlNWBrowser: NWBrowser?
    private let nwQueue = DispatchQueue(label: "com.never88gone.thlbrowserios.nwdiscovery", qos: .userInitiated)
    
    private var services: [String: NetService] = [:]
    private var deviceMap: [String: HSBDiscoveredAppleTV] = [:]
    
    private let discoveryLock = NSRecursiveLock()
    private var observers: [String: ([HSBDiscoveredAppleTV]) -> Void] = [:]
    
    @objc public private(set) var isScanning: Bool = false
    @objc public var discoveredDevices: [HSBDiscoveredAppleTV] {
        discoveryLock.lock()
        defer { discoveryLock.unlock() }
        return Array(deviceMap.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Discovery APIs
    
    @objc(startScanningWithOnChange:)
    public func startScanning(onChange: @escaping ([HSBDiscoveredAppleTV]) -> Void) {
        startScanning(observerId: "default", onChange: onChange)
    }
    
    /// 注册独立观察者 ID 并按需启动硬件发现，避免多个模块互相覆盖回调或重复清空已有扫描成果
    public func startScanning(observerId: String, onChange: @escaping ([HSBDiscoveredAppleTV]) -> Void) {
        discoveryLock.lock()
        observers[observerId] = onChange
        let alreadyRunning = isScanning && companionBrowser != nil && thlTVBrowser != nil
        let snapshot = Array(deviceMap.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if !alreadyRunning {
            isScanning = true
        }
        discoveryLock.unlock()
        
        if alreadyRunning {
            DispatchQueue.main.async {
                onChange(snapshot)
            }
            return
        }
        
        beginBrowsingServices(clearExisting: true)
    }
    
    private func beginBrowsingServices(clearExisting: Bool) {
        companionBrowser?.stop()
        companionBrowser = nil
        thlNWBrowser?.cancel()
        thlNWBrowser = nil
        thlTVBrowser?.stop()
        thlTVBrowser = nil
        
        if clearExisting {
            discoveryLock.lock()
            deviceMap.removeAll()
            services.removeAll()
            discoveryLock.unlock()
        }
        
        log.info("Starting TV & Hardware Bonjour discovery (_companion-link & _thltv)...")
        
        // 1. 扫描 糖葫芦大屏 (Android TV 及大屏浏览器专属 Bonjour 通道) - 使用现代 Network.framework NWBrowser
        startThlNWBrowser()
        
        let startOnMain = {
            // 2. 扫描 Apple TV 与 Mac 硬件 Companion Link 协议通道
            let cBrowser = NetServiceBrowser()
            cBrowser.delegate = self
            cBrowser.schedule(in: .main, forMode: .common)
            cBrowser.searchForServices(ofType: "_companion-link._tcp.", inDomain: "local.")
            self.companionBrowser = cBrowser
        }
        
        if Thread.isMainThread {
            startOnMain()
        } else {
            DispatchQueue.main.async(execute: startOnMain)
        }
    }
    
    // MARK: - Modern Network.framework Discovery for Android TV & Web Screen
    
    private func startThlNWBrowser() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_thltv._tcp", domain: nil)
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        parameters.prohibitedInterfaceTypes = [.cellular]
        
        let nwBrowser = NWBrowser(for: descriptor, using: parameters)
        nwBrowser.browseResultsChangedHandler = { [weak self] (results, changes) in
            self?.handleNWBrowserResults(results: results, changes: changes)
        }
        nwBrowser.stateUpdateHandler = { state in
            NSLog("[NWBrowser_THL] State changed: %@", "\(state)")
        }
        nwBrowser.start(queue: nwQueue)
        self.thlNWBrowser = nwBrowser
        
        // 主动探活本地开发与模拟器设备，保障本地 Android TV 模拟器 100% 出现并可直接遥控
        probeLocalCandidates()
    }
    
    private func probeLocalCandidates() {
        let localHosts = ["10.0.2.15", "127.0.0.1"]
        let port: UInt16 = 56789
        for host in localHosts {
            Self.probeTCPConnection(host: host, port: port, timeout: 0.6) { [weak self] isOnline in
                guard let self = self, isOnline else { return }
                let cleanName = "糖葫芦TV"
                let cEndpoint = nw_endpoint_create_host(host, "\(port)")
                let device = HSBDiscoveredAppleTV(
                    id: "Local_\(cleanName)",
                    name: cleanName,
                    host: host,
                    port: port,
                    modelName: "Android TV",
                    isNativeAppleTV: false,
                    isBrowserApp: true,
                    rawEndpoint: cEndpoint
                )
                self.discoveryLock.lock()
                if self.deviceMap[cleanName] == nil {
                    self.deviceMap[cleanName] = device
                }
                self.discoveryLock.unlock()
                NSLog("[LocalProbe_THL] Active local Android TV found at %@:%d", host, port)
                self.notifyChange()
            }
        }
    }
    
    private func handleNWBrowserResults(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            if case let .removed(res) = change {
                if case let .service(name, _, _, _) = res.endpoint {
                    var cleanName = name
                    if let range = cleanName.range(of: " (") {
                        cleanName = String(cleanName[..<range.lowerBound])
                    }
                    discoveryLock.lock()
                    let removed = deviceMap.removeValue(forKey: cleanName) != nil
                    discoveryLock.unlock()
                    if removed {
                        notifyChange()
                    }
                }
            }
        }
        
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            var cleanName = name
            if let range = cleanName.range(of: " (") {
                cleanName = String(cleanName[..<range.lowerBound])
            }
            
            var txtDict: [String: String] = [:]
            if case let .bonjour(txtRecord) = result.metadata {
                txtDict = txtRecord.dictionary
            }
            
            let candidateIP = txtDict["ip"] ?? txtDict["host"]
            let portStr = txtDict["port"] ?? "56789"
            let port = UInt16(portStr) ?? 56789
            let model = txtDict["model"] ?? "Android TV"
            
            probeAndRegisterNWDevice(
                endpoint: result.endpoint,
                cleanName: cleanName,
                candidateIP: candidateIP,
                port: port,
                modelName: model
            )
        }
    }
    
    private func probeAndRegisterNWDevice(
        endpoint: NWEndpoint,
        cleanName: String,
        candidateIP: String?,
        port: UInt16,
        modelName: String
    ) {
        let targetHost = candidateIP ?? "10.0.2.15"
        let probe = NWConnection(to: endpoint, using: .tcp)
        let queue = DispatchQueue(label: "com.tanghulu.nwprobe.\(cleanName)", qos: .userInitiated)
        let lock = NSLock()
        var completed = false
        
        let finish = { [weak self] (success: Bool, resolvedHost: String) in
            lock.lock()
            guard !completed else {
                lock.unlock()
                return
            }
            completed = true
            lock.unlock()
            probe.cancel()
            
            guard let self = self, success else { return }
            
            let cEndpoint = nw_endpoint_create_host(resolvedHost, "\(port)")
            let device = HSBDiscoveredAppleTV(
                id: cleanName,
                name: cleanName,
                host: resolvedHost,
                port: port,
                modelName: modelName,
                isNativeAppleTV: false,
                isBrowserApp: true,
                rawEndpoint: cEndpoint
            )
            
            self.discoveryLock.lock()
            self.deviceMap[cleanName] = device
            self.discoveryLock.unlock()
            
            NSLog("[NWBrowser_THL] Successfully discovered & probed Android TV: %@ at %@:%d", cleanName, resolvedHost, port)
            self.notifyChange()
        }
        
        probe.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(true, targetHost)
            case .failed, .cancelled:
                if let ip = candidateIP {
                    Self.probeTCPConnection(host: ip, port: port, timeout: 0.8) { ok in
                        if ok {
                            finish(true, ip)
                        } else {
                            // 降级尝试 127.0.0.1 探活（应对本地 adb forward 调试场景）
                            Self.probeTCPConnection(host: "127.0.0.1", port: port, timeout: 0.5) { localOk in
                                finish(localOk, localOk ? "127.0.0.1" : targetHost)
                            }
                        }
                    }
                } else {
                    finish(false, targetHost)
                }
            default:
                break
            }
        }
        
        probe.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 1.2) {
            finish(false, targetHost)
        }
    }
    
    @objc public func refresh() {
        discoveryLock.lock()
        let activeServices = Array(services.values)
        isScanning = true
        deviceMap.removeAll()
        discoveryLock.unlock()
        notifyChange()
        
        for service in activeServices {
            service.resolve(withTimeout: 5.0)
        }
        
        beginBrowsingServices(clearExisting: true)
    }
    
    @objc public func stopScanning() {
        companionBrowser?.stop()
        companionBrowser = nil
        thlNWBrowser?.cancel()
        thlNWBrowser = nil
        thlTVBrowser?.stop()
        thlTVBrowser = nil
        
        discoveryLock.lock()
        isScanning = false
        discoveryLock.unlock()
        
        log.info("TV & Hardware Bonjour discovery stopped.")
    }
    
    /// 使用标准 TCP 参数（非空协议栈）快速非阻塞探测指定主机端口连通性
    public static func probeTCPConnection(
        host: String,
        port: UInt16,
        timeout: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            completion(false)
            return
        }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let probeQueue = DispatchQueue(label: "com.tanghulu.tcp.probe.\(host).\(port)", qos: .userInitiated)
        let lock = NSLock()
        var finished = false

        let done: (Bool) -> Void = { success in
            lock.lock()
            let shouldComplete = !finished
            if shouldComplete {
                finished = true
            }
            lock.unlock()
            guard shouldComplete else { return }
            conn.cancel()
            completion(success)
        }

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                done(true)
            case .failed, .cancelled:
                done(false)
            default:
                break
            }
        }
        conn.start(queue: probeQueue)
        probeQueue.asyncAfter(deadline: .now() + timeout) {
            done(false)
        }
    }
    
    // MARK: - Port Knocking Wakeup (深度休眠唤醒)
    
    /// 向 Apple TV 的常用唤醒端口发起短暂 TCP 握手，触发局域网 Sleep Proxy 唤醒
    @objc public func wakeDevice(host: String, completion: ((Bool) -> Void)? = nil) {
        let knockPorts: [UInt16] = [3689, 7000, 49152, 49153]
        let group = DispatchGroup()
        let lock = NSLock()
        var atLeastOne = false
        
        for port in knockPorts {
            group.enter()
            Self.probeTCPConnection(host: host, port: port, timeout: 0.5) { success in
                if success {
                    lock.lock()
                    atLeastOne = true
                    lock.unlock()
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion?(atLeastOne)
        }
    }
    
    // MARK: - Internal Resolution & Filtering (核心过滤算法)
    
    fileprivate func processResolved(_ service: NetService) {
        let serviceType = service.type
        let serviceName = service.name
        NSLog("[BONJOUR_TRACE] didResolve name=%@, type=%@", serviceName, serviceType)
        
        let isCompanion = serviceType.contains("_companion-link")
        let isThlTV = serviceType.contains("_thltv")
        
        // 核心原生架构：支持 Apple TV 物理硬件 (_companion-link) 与 糖葫芦大屏 (_thltv)
        guard isCompanion || isThlTV else {
            return
        }
        
        var cleanName = serviceName
        if let range = cleanName.range(of: " (") {
            cleanName = String(cleanName[..<range.lowerBound])
        }
        
        var props: [String: String] = [:]
        if let txtData = service.txtRecordData(), !txtData.isEmpty {
            let txtDict = NetService.dictionary(fromTXTRecord: txtData)
            for (key, value) in txtDict {
                if let str = String(data: value, encoding: .utf8) {
                    props[key] = str
                }
            }
        }
        
        // 处理主机名与端口：优先从 Bonjour 解析出的 sockaddr 数据中提取真实 IPv4 数字地址，避免 mDNS 寻址失败
        var bestIPv4: String? = nil
        var fallbackIPv4: String? = nil
        if let addresses = service.addresses {
            for addrData in addresses {
                addrData.withUnsafeBytes { rawPtr in
                    guard let sa = rawPtr.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return }
                    if sa.pointee.sa_family == sa_family_t(AF_INET) {
                        let sin = rawPtr.baseAddress!.assumingMemoryBound(to: sockaddr_in.self)
                        var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        var sinAddr = sin.pointee.sin_addr
                        if inet_ntop(AF_INET, &sinAddr, &ipBuf, socklen_t(INET_ADDRSTRLEN)) != nil {
                            let ip = String(cString: ipBuf)
                            if ip.starts(with: "192.168.") || ip.starts(with: "10.") || ip.starts(with: "172.") {
                                bestIPv4 = ip
                            } else if !ip.starts(with: "198.18.") && !ip.starts(with: "169.254.") && !ip.starts(with: "127.") {
                                if bestIPv4 == nil { bestIPv4 = ip }
                            } else {
                                if fallbackIPv4 == nil { fallbackIPv4 = ip }
                            }
                        }
                    }
                }
            }
        }
        let resolvedIPv4 = bestIPv4 ?? fallbackIPv4
        
        var host = resolvedIPv4 ?? service.hostName ?? "\(serviceName).local"
        if host.hasSuffix(".") {
            host = String(host.dropLast())
        }
        // 若 host 包含中文或空格，安全过滤以确保 URLComponents 可用
        if host.contains(" ") || host.range(of: "\\p{Han}", options: .regularExpression) != nil {
            if let hn = service.hostName, !hn.isEmpty {
                host = hn.hasSuffix(".") ? String(hn.dropLast()) : hn
            }
        }
        
        // 分支 1：如果是 糖葫芦大屏 (_thltv)
        if isThlTV {
            let port = service.port > 0 ? UInt16(service.port) : 56789
            let endpoint = nw_endpoint_create_host(host, "\(port)")
            let model = props["model"] ?? "Android TV"
            
            // 真实物理探活：只有端口 56789 真实处于监听并可握手状态的大屏，才允许展示给用户，杜绝假设备与幽灵设备
            Self.probeTCPConnection(host: host, port: port, timeout: 0.8) { [weak self] isReachable in
                guard let self = self else { return }
                guard isReachable else {
                    NSLog("[BONJOUR_TRACE] Filtered out unreachable TV: %@ at %@:%d", cleanName, host, port)
                    self.discoveryLock.lock()
                    let removed = self.deviceMap.removeValue(forKey: cleanName) != nil
                    self.discoveryLock.unlock()
                    if removed {
                        self.notifyChange()
                    }
                    return
                }
                
                let dev = HSBDiscoveredAppleTV(
                    id: cleanName,
                    name: cleanName,
                    host: host,
                    port: port,
                    modelName: model,
                    isNativeAppleTV: false,
                    isBrowserApp: true,
                    rawEndpoint: endpoint
                )
                self.discoveryLock.lock()
                self.deviceMap[cleanName] = dev
                self.discoveryLock.unlock()
                self.notifyChange()
            }
            return
        }
        
        // 分支 2：如果是 Apple TV 或 Mac 隔空播放设备 (_companion-link)
        let modelName = props["rpMd"] ?? props["model"]
        let flagStr = props["rpFl"] ?? "0x0"
        let flags = UInt64(flagStr.replacingOccurrences(of: "0x", with: ""), radix: 16) ?? 0
        
        log.info("Resolved Companion: \(serviceName) model=\(modelName ?? "nil") flags=0x\(String(flags, radix: 16))")
        NSLog("[BONJOUR_TRACE] Companion flags=0x%llx, model=%@ for %@", flags, modelName ?? "nil", serviceName)
        
        let isDeviceMac: Bool = {
            let lowerM = (modelName ?? "").lowercased()
            let lowerN = cleanName.lowercased()
            return lowerM.contains("mac") || lowerN.contains("mac")
        }()
        let isAppleTV = (flags & 0x4000 != 0) || (modelName != nil && modelName!.contains("AppleTV"))
        
        guard isAppleTV || isDeviceMac else {
            discoveryLock.lock()
            deviceMap.removeValue(forKey: cleanName)
            discoveryLock.unlock()
            notifyChange()
            log.info("Filtered out unsupported companion device: \(serviceName)")
            NSLog("[BONJOUR_TRACE] Filtered out unsupported: %@", serviceName)
            return
        }
        
        let port = service.port > 0 ? UInt16(service.port) : 49152
        
        NSLog("[ATV_CONNECT] Bonjour resolved: %@ -> host=%@ (IPv4=%@, hostName=%@), port=%d (raw=%d), addrs=%d",
              cleanName, host, resolvedIPv4 ?? "nil", service.hostName ?? "nil", Int(port), Int(service.port), service.addresses?.count ?? 0)
        
        discoveryLock.lock()
        defer { discoveryLock.unlock() }
        
        let endpoint = nw_endpoint_create_host(host, "\(port)")
        
        let device = HSBDiscoveredAppleTV(
            id: cleanName,
            name: cleanName,
            host: host,
            port: port,
            modelName: modelName,
            isNativeAppleTV: !isDeviceMac,
            isBrowserApp: false,
            rawEndpoint: endpoint
        )
        
        deviceMap[cleanName] = device
        notifyChange()
    }
    
    fileprivate func notifyChange() {
        discoveryLock.lock()
        let current = Array(deviceMap.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let handlers = Array(observers.values)
        discoveryLock.unlock()
        
        let names = current.map { "\($0.name) (\($0.modelName ?? "nil"))" }.joined(separator: ", ")
        NSLog("[BONJOUR_TRACE] notifyChange: %d devices: %@", current.count, names)
        DispatchQueue.main.async {
            for handler in handlers {
                handler(current)
            }
            NotificationCenter.default.post(name: HSBAppleTVDiscovery.devicesDidChangeNotification, object: current)
        }
    }
}

// MARK: - NetServiceBrowserDelegate & NetServiceDelegate

extension HSBAppleTVDiscovery: NetServiceBrowserDelegate {
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        log.info("Found Bonjour service: \(service.name) (\(service.type))")
        discoveryLock.lock()
        let key = "\(service.name).\(service.type)"
        services[key] = service
        discoveryLock.unlock()
        
        service.delegate = self
        service.schedule(in: .main, forMode: .common)
        service.resolve(withTimeout: 5.0)
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        log.info("Removed Bonjour service: \(service.name) (\(service.type))")
        discoveryLock.lock()
        let key = "\(service.name).\(service.type)"
        services.removeValue(forKey: key)
        
        var cleanName = service.name
        if let range = cleanName.range(of: " (") {
            cleanName = String(cleanName[..<range.lowerBound])
        }
        
        // 若该名称下已无其它服务，则从设备列表中移除
        let remainingForName = services.values.filter { s in
            var n = s.name
            if let r = n.range(of: " (") { n = String(n[..<r.lowerBound]) }
            return n == cleanName
        }
        if remainingForName.isEmpty {
            deviceMap.removeValue(forKey: cleanName)
        }
        discoveryLock.unlock()
        
        notifyChange()
    }
}

extension HSBAppleTVDiscovery: NetServiceDelegate {
    public func netServiceDidResolveAddress(_ sender: NetService) {
        processResolved(sender)
    }
    
    public func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        processResolved(sender)
    }
    
    public func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        log.warning("Failed to resolve \(sender.name): \(errorDict)")
    }
}
