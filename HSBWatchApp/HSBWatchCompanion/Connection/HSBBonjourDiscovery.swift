//
//  HSBBonjourDiscovery.swift
//  HSBWatchCompanion
//
//  Created for Milestone 1 Feature #3: Modern Bonjour Discovery with Offline Sensing.
//

import Foundation
import Network
import Combine
import os.log

/// 发现的电视端设备元数据模型
public struct HSBDiscoveredDevice: Identifiable, Hashable, Equatable, Sendable {
    /// 唯一标识符（优先采用 TXTRecord 中的 id / deviceID，降级使用 serviceName.serviceType.domain）
    public let id: String
    
    /// Bonjour 服务广播名称 (例如 "客厅电视", "hsbtvbrowser")
    public let name: String
    
    /// 服务类型 (例如 "_thltv._tcp")
    public let serviceType: String
    
    /// 所在域名 (通常为 "local.")
    public let domain: String
    
    /// 底层 Network.framework 端点，供建立 nw_connection_t
    public let endpoint: NWEndpoint
    
    /// TXT 记录键值字典
    public let txtRecord: [String: String]
    
    /// 发现时所依赖的网络接口名称 (如 en0, awdl0)
    public let interfaceName: String?
    
    /// 是否支持 AWDL 点对点直连
    public let supportsP2P: Bool
    
    /// 最后一次被探测到的时间戳
    public var lastSeen: Date
    
    public init(
        id: String,
        name: String,
        serviceType: String,
        domain: String,
        endpoint: NWEndpoint,
        txtRecord: [String: String] = [:],
        interfaceName: String? = nil,
        supportsP2P: Bool = false,
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.serviceType = serviceType
        self.domain = domain
        self.endpoint = endpoint
        self.txtRecord = txtRecord
        self.interfaceName = interfaceName
        self.supportsP2P = supportsP2P
        self.lastSeen = lastSeen
    }
    
    // Hashable & Equatable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: HSBDiscoveredDevice, rhs: HSBDiscoveredDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Bonjour 设备发现代理协议
public protocol HSBBonjourDiscoveryDelegate: AnyObject {
    /// 发现新设备加入
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didFind device: HSBDiscoveredDevice)
    /// 检测到设备下线/离开（修复残留关键回调）
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didLose device: HSBDiscoveredDevice)
    /// 设备列表全量更新（经过 100ms 防抖归并排序）
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didUpdateDevices devices: [HSBDiscoveredDevice])
    /// 扫描状态改变
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didChangeScanningState isScanning: Bool)
    /// 扫描异常中断
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didFailWithError error: NWError)
}

// 提供默认实现，简化调用方使用
public extension HSBBonjourDiscoveryDelegate {
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didFind device: HSBDiscoveredDevice) {}
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didLose device: HSBDiscoveredDevice) {}
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didUpdateDevices devices: [HSBDiscoveredDevice]) {}
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didChangeScanningState isScanning: Bool) {}
    func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didFailWithError error: NWError) {}
}

/// 现代 Bonjour 设备发现服务
/// 基于 Network.framework 的 NWBrowser，原生支持 Wi-Fi 与 AWDL/P2P 直连，
/// 严格感知并处理 .removed 设备下线事件，带 100ms 防抖与 NWPathMonitor 网络自愈
public final class HSBBonjourDiscovery: NSObject, ObservableObject {
    
    // MARK: - Constants
    public static let defaultServiceType = "_thltv._tcp"
    private static let logger = Logger(subsystem: "com.never88gone.thlbrowserios", category: "BonjourDiscovery")
    
    // MARK: - Published Properties (SwiftUI / Combine)
    @Published public private(set) var discoveredDevices: [HSBDiscoveredDevice] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var isNetworkAvailable: Bool = true
    
    // MARK: - Delegate
    public weak var delegate: HSBBonjourDiscoveryDelegate?
    
    // MARK: - Private Properties
    private let serviceType: String
    private var browser: NWBrowser?
    private let browserQueue = DispatchQueue(label: "com.never88gone.thlbrowserios.bonjour.queue", qos: .userInitiated)
    
    // 内部设备持久化字典：Key 为 device.id
    private var deviceCatalog: [String: HSBDiscoveredDevice] = [:]
    private let catalogLock = NSLock()
    
    // 网络路径监听器
    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.never88gone.thlbrowserios.pathmonitor.queue", qos: .utility)
    
    // 防抖计时器 (Debounce Timer)，防止局域网广播风暴导致 UI 连续频繁刷新
    private var debounceTimer: DispatchSourceTimer?
    private let debounceInterval: TimeInterval = 0.1 // 100ms
    
    // MARK: - Initialization
    public init(serviceType: String = HSBBonjourDiscovery.defaultServiceType) {
        self.serviceType = serviceType
        self.pathMonitor = NWPathMonitor()
        super.init()
        setupPathMonitor()
    }
    
    deinit {
        stopDiscovery()
        pathMonitor.cancel()
    }
    
    // MARK: - Network Path Monitoring
    private func setupPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isAvailable = (path.status == .satisfied)
            let isWifiOrEthernet = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
            
            Self.logger.info("[PathMonitor] Status: \(String(describing: path.status)), WiFi/Ethernet: \(isWifiOrEthernet)")
            
            DispatchQueue.main.async {
                self.isNetworkAvailable = isAvailable
            }
            
            self.browserQueue.async {
                if !isAvailable {
                    Self.logger.warning("[PathMonitor] Network dropped. Clearing devices.")
                    self.clearDevices()
                } else if self.isScanning {
                    Self.logger.info("[PathMonitor] Network restored. Refreshing browser...")
                    self.restartBrowser()
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Public Control APIs
    
    /// 开始扫描 Bonjour 设备
    public func startDiscovery() {
        browserQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isScanning {
                Self.logger.info("Bonjour discovery already running.")
                return
            }
            self.isScanning = true
            DispatchQueue.main.async {
                self.delegate?.bonjourDiscovery(self, didChangeScanningState: true)
            }
            self.startBrowserInternal()
        }
    }
    
    /// 停止扫描
    public func stopDiscovery() {
        browserQueue.async { [weak self] in
            guard let self = self else { return }
            self.cancelDebounceTimer()
            if let browser = self.browser {
                browser.cancel()
                self.browser = nil
            }
            self.isScanning = false
            DispatchQueue.main.async {
                self.delegate?.bonjourDiscovery(self, didChangeScanningState: false)
            }
            Self.logger.info("Bonjour discovery stopped.")
        }
    }
    
    /// 强制刷新（清空现有列表并重新扫描）
    public func refresh() {
        browserQueue.async { [weak self] in
            guard let self = self else { return }
            self.clearDevices()
            self.restartBrowser()
        }
    }
    
    // MARK: - Browser Engine Implementation
    
    private func createBrowserParameters() -> NWParameters {
        let parameters = NWParameters()
        // 关键特性：开启 AWDL / P2P 支持，实现免局域网直连或同频直通
        parameters.includePeerToPeer = true
        
        // 禁用蜂窝网络扫描，避免在离开 Wi-Fi 时尝试对移动蜂窝子网进行无效多播
        parameters.prohibitedInterfaceTypes = [.cellular]
        
        return parameters
    }
    
    private func startBrowserInternal() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: self.serviceType, domain: nil)
        let parameters = createBrowserParameters()
        let browser = NWBrowser(for: descriptor, using: parameters)
        
        browser.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            Self.logger.info("[NWBrowser] State changed to: \(String(describing: newState))")
            switch newState {
            case .ready:
                Self.logger.info("NWBrowser is ready and scanning for \(self.serviceType)...")
            case .failed(let error):
                Self.logger.error("NWBrowser failed with error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.delegate?.bonjourDiscovery(self, didFailWithError: error)
                }
            case .cancelled:
                Self.logger.info("NWBrowser cancelled.")
            default:
                break
            }
        }
        
        // 核心处理：完整处理 Set<NWBrowser.Result.Change>，捕获下线事件
        browser.browseResultsChangedHandler = { [weak self] (results, changes) in
            guard let self = self else { return }
            self.handleBrowseChanges(results: results, changes: changes)
        }
        
        browser.start(queue: self.browserQueue)
        self.browser = browser
    }
    
    private func restartBrowser() {
        if let browser = self.browser {
            browser.cancel()
            self.browser = nil
        }
        startBrowserInternal()
    }
    
    // MARK: - Change Processing & Device Offline Resolution
    
    private func handleBrowseChanges(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        catalogLock.lock()
        var addedList: [HSBDiscoveredDevice] = []
        var removedList: [HSBDiscoveredDevice] = []
        
        for change in changes {
            switch change {
            case .identical:
                break
                
            case .added(let result):
                if let device = parseDevice(from: result) {
                    self.deviceCatalog[device.id] = device
                    addedList.append(device)
                    Self.logger.info("[Device Added] \(device.name) (\(device.id))")
                }
                
            case .removed(let result):
                // 核心修复：捕获下线事件，从内存字典彻底剔除已离线设备
                let deviceId = extractDeviceId(from: result)
                if let removedDevice = self.deviceCatalog.removeValue(forKey: deviceId) {
                    removedList.append(removedDevice)
                    Self.logger.info("[Device Removed] \(removedDevice.name) (\(removedDevice.id))")
                } else {
                    // 若通过 ID 找不到，按 endpoint 比对 fallback 剔除
                    let endpoint = result.endpoint
                    if let key = self.deviceCatalog.first(where: { $0.value.endpoint == endpoint })?.key,
                       let dev = self.deviceCatalog.removeValue(forKey: key) {
                        removedList.append(dev)
                        Self.logger.info("[Device Removed by Endpoint] \(dev.name) (\(dev.id))")
                    }
                }
                
            case .changed(let oldResult, let newResult, let flags):
                _ = oldResult
                Self.logger.debug("[Device Changed] Flags: \(flags.rawValue)")
                if let updatedDevice = parseDevice(from: newResult) {
                    self.deviceCatalog[updatedDevice.id] = updatedDevice
                }
            @unknown default:
                break
            }
        }
        
        catalogLock.unlock()
        
        // 单个事件回调通知
        for dev in addedList {
            DispatchQueue.main.async {
                self.delegate?.bonjourDiscovery(self, didFind: dev)
            }
        }
        for dev in removedList {
            DispatchQueue.main.async {
                self.delegate?.bonjourDiscovery(self, didLose: dev)
            }
        }
        
        // 触发防抖更新整个设备列表
        scheduleDebouncedNotification()
    }
    
    // MARK: - Device Parsing & Identification
    
    private func extractDeviceId(from result: NWBrowser.Result) -> String {
        switch result.endpoint {
        case .service(let name, let type, let domain, _):
            return "\(name).\(type).\(domain)"
        default:
            return result.endpoint.debugDescription
        }
    }
    
    private func parseDevice(from result: NWBrowser.Result) -> HSBDiscoveredDevice? {
        let endpoint = result.endpoint
        guard case .service(let name, let type, let domain, _) = endpoint else {
            return nil
        }
        
        // 解析 TXT 记录
        var txtDict: [String: String] = [:]
        if case .bonjour(let txtRecord) = result.metadata {
            txtDict = txtRecord.dictionary
        }
        
        // 提取主要接口
        var ifName: String? = nil
        var isP2P = false
        for iface in result.interfaces {
            if iface.type == .wifi {
                ifName = iface.name
            }
            if iface.name.contains("awdl") {
                isP2P = true
            }
        }
        
        // 唯一 ID 优先使用 TXTRecord 中的 id，否则使用 name.type.domain
        let uniqueId = txtDict["id"] ?? "\(name).\(type).\(domain)"
        
        return HSBDiscoveredDevice(
            id: uniqueId,
            name: name,
            serviceType: type,
            domain: domain,
            endpoint: endpoint,
            txtRecord: txtDict,
            interfaceName: ifName,
            supportsP2P: isP2P,
            lastSeen: Date()
        )
    }
    
    // MARK: - Debouncing Engine
    
    private func scheduleDebouncedNotification() {
        catalogLock.lock()
        cancelDebounceTimer()
        
        let timer = DispatchSource.makeTimerSource(queue: self.browserQueue)
        timer.schedule(deadline: .now() + self.debounceInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.publishDeviceCatalog()
        }
        timer.resume()
        self.debounceTimer = timer
        catalogLock.unlock()
    }
    
    private func cancelDebounceTimer() {
        if let timer = self.debounceTimer {
            timer.cancel()
            self.debounceTimer = nil
        }
    }
    
    private func publishDeviceCatalog() {
        catalogLock.lock()
        let snapshot = Array(self.deviceCatalog.values).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        catalogLock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.discoveredDevices = snapshot
            self.delegate?.bonjourDiscovery(self, didUpdateDevices: snapshot)
        }
    }
    
    private func clearDevices() {
        catalogLock.lock()
        self.deviceCatalog.removeAll()
        catalogLock.unlock()
        publishDeviceCatalog()
    }
}
