//
//  HSBAppleTVDiscovery.swift
//  HSBWatchCompanion
//
//  精准参考开源参考工程 itsytv-macos (DeviceDiscovery.swift) 的 Apple TV 局域网 Bonjour 发现与过滤架构。
//  支持 _companion-link._tcp、_airplay._tcp 与 _thltv._tcp 多通道并发扫描、TXT 记录解析与端口敲门唤醒。
//

import Foundation
import Network
import os.log

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
    
    @objc public var displaySubtitle: String {
        if isDualMode {
            return "双模聚合 · Apple TV 系统遥控 + 浏览器"
        } else if isNativeAppleTV {
            if let model = modelName, !model.isEmpty {
                return "Apple TV (\(model)) · 系统原生遥控就绪"
            }
            return "Apple TV · 系统原生遥控就绪"
        } else if isBrowserApp {
            return "糖葫芦大屏浏览器 · WebKit 触控就绪"
        } else {
            return "大屏设备 · 点击连接"
        }
    }
}

/// 局域网 Apple TV 自动发现引擎 (参考 itsytv-macos DeviceDiscovery)
@objc public final class HSBAppleTVDiscovery: NSObject {
    @objc public static let shared = HSBAppleTVDiscovery()
    
    private var companionBrowser: NetServiceBrowser?
    private var browserAppBrowser: NetServiceBrowser?
    
    private var services: [String: NetService] = [:]
    private var deviceMap: [String: HSBDiscoveredAppleTV] = [:]
    
    private let discoveryLock = NSLock()
    private var onChangeCallback: (([HSBDiscoveredAppleTV]) -> Void)?
    
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
        discoveryLock.lock()
        self.onChangeCallback = onChange
        self.isScanning = true
        self.deviceMap.removeAll()
        self.services.removeAll()
        discoveryLock.unlock()
        
        log.info("Starting Apple TV Bonjour discovery (_companion-link, _thltv)...")
        
        // 1. 扫描 Apple TV Companion Link 协议通道 (itsytv-macos 核心扫描服务)
        let cBrowser = NetServiceBrowser()
        cBrowser.delegate = self
        cBrowser.schedule(in: .main, forMode: .common)
        cBrowser.searchForServices(ofType: "_companion-link._tcp.", inDomain: "local.")
        self.companionBrowser = cBrowser
        
        // 2. 扫描糖葫芦大屏浏览器通道
        let bBrowser = NetServiceBrowser()
        bBrowser.delegate = self
        bBrowser.schedule(in: .main, forMode: .common)
        bBrowser.searchForServices(ofType: "_thltv._tcp.", inDomain: "local.")
        self.browserAppBrowser = bBrowser
    }
    
    @objc public func refresh() {
        discoveryLock.lock()
        for service in services.values {
            service.resolve(withTimeout: 5.0)
        }
        discoveryLock.unlock()
        
        stopScanning()
        if let callback = onChangeCallback {
            startScanning(onChange: callback)
        }
    }
    
    @objc public func stopScanning() {
        companionBrowser?.stop()
        companionBrowser = nil
        
        browserAppBrowser?.stop()
        browserAppBrowser = nil
        
        discoveryLock.lock()
        isScanning = false
        discoveryLock.unlock()
        
        log.info("Apple TV Bonjour discovery stopped.")
    }
    
    // MARK: - Port Knocking Wakeup (itsytv-macos 深度休眠唤醒)
    
    /// 向 Apple TV 的常用唤醒端口发起短暂 TCP 握手，触发局域网 Sleep Proxy 唤醒
    @objc public func wakeDevice(host: String, completion: ((Bool) -> Void)? = nil) {
        let knockPorts: [UInt16] = [3689, 7000, 49152, 49153]
        let group = DispatchGroup()
        let lock = NSLock()
        var atLeastOne = false
        let queue = DispatchQueue(label: "com.never88gone.thlbrowserios.wake", qos: .userInitiated)
        
        for port in knockPorts {
            group.enter()
            let endpoint = nw_endpoint_create_host(host, "\(port)")
            let params = nw_parameters_create()
            let conn = nw_connection_create(endpoint, params)
            nw_connection_set_queue(conn, queue)
            
            var didFinish = false
            let finish = { (success: Bool) in
                if !didFinish {
                    didFinish = true
                    if success {
                        lock.lock()
                        atLeastOne = true
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
            queue.asyncAfter(deadline: .now() + 0.5) {
                finish(false)
            }
        }
        
        group.notify(queue: .main) {
            completion?(atLeastOne)
        }
    }
    
    // MARK: - Internal Resolution & Filtering (itsytv-macos 核心过滤算法)
    
    fileprivate func processResolved(_ service: NetService) {
        let serviceType = service.type
        let serviceName = service.name
        NSLog("[BONJOUR_TRACE] didResolve name=%@, type=%@", serviceName, serviceType)
        
        var modelName: String? = nil
        var isAppleTV = false
        var isBrowser = false
        
        if serviceType.contains("_thltv") {
            isBrowser = true
        }
        
        var cleanName = serviceName
        if let range = cleanName.range(of: " (") {
            cleanName = String(cleanName[..<range.lowerBound])
        }
        
        if serviceType.contains("_companion-link") {
            guard let txtData = service.txtRecordData(), !txtData.isEmpty else {
                log.info("No TXT data yet for \(serviceName)")
                return
            }
            let txtDict = NetService.dictionary(fromTXTRecord: txtData)
            var props: [String: String] = [:]
            for (key, value) in txtDict {
                if let str = String(data: value, encoding: .utf8) {
                    props[key] = str
                }
            }
            
            modelName = props["rpMd"] ?? props["model"]
            let flagStr = props["rpFl"] ?? "0x0"
            let flags = UInt64(flagStr.replacingOccurrences(of: "0x", with: ""), radix: 16) ?? 0
            
            log.info("Resolved Companion: \(serviceName) model=\(modelName ?? "nil") flags=0x\(String(flags, radix: 16))")
            NSLog("[BONJOUR_TRACE] Companion flags=0x%llx, model=%@ for %@", flags, modelName ?? "nil", serviceName)
            
            // 核心过滤规则 (参考 itsytv-macos DeviceDiscovery.swift:65-72)
            // 只有 flags & 0x4000 != 0 才是具备 PIN 码原生配对能力的 Apple TV (彻底排除同一局域网的 Mac、iPhone、HomePod)
            guard (flags & 0x4000 != 0) || (modelName != nil && modelName!.contains("AppleTV")) else {
                discoveryLock.lock()
                deviceMap.removeValue(forKey: cleanName)
                discoveryLock.unlock()
                notifyChange()
                log.info("Filtered out non-AppleTV companion device: \(serviceName)")
                NSLog("[BONJOUR_TRACE] Filtered out non-AppleTV: %@", serviceName)
                return
            }
            isAppleTV = true
        }
        
        // 若既不是 Apple TV 也不是糖葫芦大屏浏览器，直接忽略
        guard isAppleTV || isBrowser else {
            return
        }
        
        // 处理主机名与端口
        var host = service.hostName ?? "\(serviceName).local"
        if host.hasSuffix(".") {
            host = String(host.dropLast())
        }
        let port = service.port > 0 ? UInt16(service.port) : (isBrowser ? 56789 : 49152)
        
        discoveryLock.lock()
        defer { discoveryLock.unlock() }
        
        // 查找或合并已有记录
        let existing = deviceMap[cleanName]
        let finalIsNative = isAppleTV || (existing?.isNativeAppleTV ?? false)
        let finalIsBrowser = isBrowser || (existing?.isBrowserApp ?? false)
        let finalModel = modelName ?? existing?.modelName
        let finalPort = (isBrowser && !isAppleTV) ? port : (existing?.port ?? port)
        let finalHost = !host.isEmpty ? host : (existing?.host ?? "")
        
        let endpoint = nw_endpoint_create_host(finalHost, "\(finalPort)")
        
        let device = HSBDiscoveredAppleTV(
            id: cleanName,
            name: cleanName,
            host: finalHost,
            port: finalPort,
            modelName: finalModel,
            isNativeAppleTV: finalIsNative,
            isBrowserApp: finalIsBrowser,
            rawEndpoint: endpoint
        )
        
        deviceMap[cleanName] = device
        notifyChange()
    }
    
    fileprivate func notifyChange() {
        let current = Array(deviceMap.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let names = current.map { "\($0.name) (\($0.modelName ?? "nil"))" }.joined(separator: ", ")
        NSLog("[BONJOUR_TRACE] notifyChange: %d devices: %@", current.count, names)
        DispatchQueue.main.async { [weak self] in
            self?.onChangeCallback?(current)
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
