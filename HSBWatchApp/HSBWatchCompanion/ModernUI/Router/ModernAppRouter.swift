//
//  ModernAppRouter.swift
//  HSBWatchCompanion
//
//  全局纯 SwiftUI 导航路由中心与原生系统能力桥接：
//  1. 维护 NavigationStack 路径栈与全局 Modal 弹窗状态；
//  2. 承接全部 `hsbremote://` 深度链接路由与跨模块 NotificationCenter 跳转信号；
//  3. 通过 UIViewControllerRepresentable 轻量封装相机扫码与内置 Safari 浏览能力。
//

import SwiftUI
import UIKit
import SafariServices
import Combine

public enum HSBAppRoute: Hashable {
    case remote
    case settings
    case aiModelCenter
    case llmTest
    case openSourceLibraries
    case contactUs
    case privacyPolicy
    case about
}

@MainActor
public final class HSBAppRouter: ObservableObject {
    public static let shared = HSBAppRouter()
    
    @Published public var path: [HSBAppRoute] = []
    @Published public var isQRScannerPresented: Bool = false
    @Published public var activeGuideType: ConnectionGuideType? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationObservers()
    }
    
    public func push(_ route: HSBAppRoute) {
        if path.last == route { return }
        path.append(route)
    }
    
    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    public func popToRoot() {
        path.removeAll()
    }
    
    private func setupNotificationObservers() {
        let nc = NotificationCenter.default
        
        // 从任意遥控或卡片触发扫码配对
        nc.publisher(for: Notification.Name("HSBOpenQRCodeScannerNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isQRScannerPresented = true
            }
            .store(in: &cancellables)
        
        // 遥控容器主动断开并退回根首页
        nc.publisher(for: Notification.Name("HSBExitRemotePageNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.path.last == .remote {
                    self.path.removeLast()
                }
            }
            .store(in: &cancellables)
        
        // 打开指引弹窗 (如由 URL Scheme 触发)
        nc.publisher(for: Notification.Name("HSBShowGuideModalNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                let kind = (note.userInfo?["type"] as? String ?? "browser").lowercased()
                self?.activeGuideType = (kind == "system") ? .system : .browser
            }
            .store(in: &cancellables)
        
        // 深度链接或快捷动作触发页面导航 (兼容 name 与 page 两种键名)
        nc.publisher(for: Notification.Name("HSBNavigateToPageNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self = self else { return }
                let targetName = (note.userInfo?["name"] as? String)
                    ?? (note.userInfo?["page"] as? String)
                    ?? "hub"
                self.navigateByName(targetName.lowercased(), userInfo: note.userInfo)
            }
            .store(in: &cancellables)
    }
    
    public func navigateByName(_ page: String, userInfo: [AnyHashable: Any]? = nil) {
        switch page {
        case "hub", "home", "root":
            popToRoot()
        case "settings":
            popToRoot()
            push(.settings)
        case "ai", "ai_center", "llm_center":
            popToRoot()
            push(.aiModelCenter)
        case "ai_lab", "llm_test":
            popToRoot()
            push(.llmTest)
        case "about":
            popToRoot()
            push(.about)
        case "open_source", "libraries":
            popToRoot()
            push(.openSourceLibraries)
        case "contact":
            popToRoot()
            push(.contactUs)
        case "privacy":
            popToRoot()
            push(.privacyPolicy)
        case "mac":
            popToRoot()
            let macDev = HSBDiscoveredAppleTV(
                id: "mac_studio",
                name: "never88gone的 Mac Studio",
                host: "127.0.0.1",
                port: 7000,
                modelName: "AppleTV18,1",
                isNativeAppleTV: true,
                isBrowserApp: false,
                rawEndpoint: nil
            )
            HSBModernRemoteBridge.setCurrentTargetDevice(macDev)
            push(.remote)
        case "remote", "browser", "iptv", "pdf", "video", "apps":
            if path.last != .remote {
                popToRoot()
                let tvDev = HSBDiscoveredAppleTV(
                    id: "hsbtv7",
                    name: "HSBTV7",
                    host: "127.0.0.1",
                    port: 7000,
                    modelName: "AppleTV14,1",
                    isNativeAppleTV: true,
                    isBrowserApp: true,
                    rawEndpoint: nil
                )
                HSBModernRemoteBridge.setCurrentTargetDevice(tvDev)
                push(.remote)
            }
            let rawTab = userInfo?["tab"]
            let tabInt: Int = (rawTab as? Int) ?? Int((rawTab as? String) ?? "") ?? -1
            if tabInt >= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    NotificationCenter.default.post(
                        name: Notification.Name("HSBSwitchRemoteTabNotification"),
                        object: nil,
                        userInfo: ["tab": tabInt]
                    )
                }
            }
        default:
            break
        }
    }
    
    /// 完整承接原 SceneDelegate 的 `hsbremote://` URL Scheme 深度链接分发
    public func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "hsbremote" else { return }
        let host = (url.host ?? "").lowercased()
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        func query(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }
        
        Log.companion.report("Router: Handling deep link URL -> \(url.absoluteString)")
        
        if host == "pair" {
            HSBTVOSConnectionManager.shared().connect(toPairingURL: url)
            return
        }
        
        if host == "pin" {
            let code = query("code") ?? url.lastPathComponent
            if !code.isEmpty {
                HSBModernRemoteBridge.submitNativePIN(code, completion: nil)
            }
            return
        }
        
        if host == "watch" {
            let action = query("action") ?? "down"
            let payload: [String: Any] = ["action": action]
            HSBWatchSessionManager.shared().handleIncomingPayload(payload)
            return
        }
        
        if host == "guide" {
            let guideType = query("type") ?? "browser"
            NotificationCenter.default.post(
                name: Notification.Name("HSBShowGuideModalNotification"),
                object: nil,
                userInfo: ["type": guideType]
            )
            return
        }
        
        if host == "page" {
            let pageName = query("name") ?? "hub"
            let tab = query("tab") ?? "0"
            NotificationCenter.default.post(
                name: Notification.Name("HSBNavigateToPageNotification"),
                object: nil,
                userInfo: ["name": pageName, "tab": tab]
            )
            return
        }
        
        if host == "key" {
            if let keyName = query("name"), !keyName.isEmpty {
                HSBModernRemoteBridge.sendCommandNamed(keyName)
                let legacyMgr = HSBTVOSConnectionManager.shared()
                switch keyName.lowercased() {
                case "right": legacyMgr.sendSimulateAction(.right)
                case "left": legacyMgr.sendSimulateAction(.left)
                case "up": legacyMgr.sendSimulateAction(.up)
                case "down": legacyMgr.sendSimulateAction(.down)
                case "select", "enter", "ok": legacyMgr.sendSimulateAction(.select)
                case "menu", "back": legacyMgr.sendSimulateAction(.menu)
                case "play", "pause", "playpause": legacyMgr.sendSimulateAction(.play)
                case "forward", "seek_forward": legacyMgr.sendSimulateAction(.seekForward)
                case "backward", "seek_backward": legacyMgr.sendSimulateAction(.seekBackward)
                case "volume_up": legacyMgr.sendSimulateAction(.volumeUp)
                case "volume_down": legacyMgr.sendSimulateAction(.volumeDown)
                default: break
                }
            }
            return
        }
        
        if host == "browser" || host == "screen" {
            let action = (query("action") ?? "").lowercased()
            let urlVal = query("url") ?? ""
            let scriptVal = query("script") ?? ""
            let dx = Double(query("dx") ?? "0") ?? 0
            let dy = Double(query("dy") ?? "0") ?? 0
            let modeVal = Int(query("mode") ?? "1") ?? 1
            let stateVal = query("state") ?? "began"
            let legacyMgr = HSBTVOSConnectionManager.shared()
            
            switch action {
            case "refresh":
                NotificationCenter.default.post(name: Notification.Name("HSBRefreshScreenChannelNotification"), object: nil)
            case "disconnect":
                NotificationCenter.default.post(name: Notification.Name("HSBDisconnectScreenChannelNotification"), object: nil)
            case "forget":
                NotificationCenter.default.post(name: Notification.Name("HSBForgetScreenChannelNotification"), object: nil)
            case "manage", "sheet":
                NotificationCenter.default.post(name: Notification.Name("HSBShowScreenManageSheetNotification"), object: nil)
            case "open_url" where !urlVal.isEmpty:
                legacyMgr.sendSimulateAction(.openUrl, withParams: [HSBRemotePayloadKeyUrl: urlVal])
            case "scroll":
                legacyMgr.sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.macScroll,
                    HSBRemotePayloadKeyDx: dx,
                    HSBRemotePayloadKeyDy: dy
                ])
            case "pan":
                legacyMgr.sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.macPan,
                    HSBRemotePayloadKeyDx: dx,
                    HSBRemotePayloadKeyDy: dy
                ])
            case "drag":
                legacyMgr.sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.macDrag,
                    HSBRemotePayloadKeyState: stateVal,
                    HSBRemotePayloadKeyDx: dx,
                    HSBRemotePayloadKeyDy: dy
                ])
            case "tap":
                legacyMgr.sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.macTap,
                    HSBRemotePayloadKeyMode: modeVal
                ])
            case "reload":
                legacyMgr.sendSimulateAction(.pageReload)
            case "home":
                legacyMgr.sendSimulateAction(.pageHome)
            case "eval", "js" where !scriptVal.isEmpty:
                legacyMgr.sendSimulateAction(.executeJS, withParams: [HSBRemotePayloadKeyScript: scriptVal])
            default:
                break
            }
            return
        }
        
        if host == "connect_device" {
            let index = Int(query("index") ?? "0") ?? 0
            NotificationCenter.default.post(
                name: Notification.Name("HSBConnectDeviceAtIndexNotification"),
                object: nil,
                userInfo: ["index": index]
            )
            return
        }
        
        if host == "pdf" {
            let cmd = (query("action") ?? query("cmd") ?? "").lowercased()
            let x = Double(query("x") ?? "0.5") ?? 0.5
            let y = Double(query("y") ?? "0.5") ?? 0.5
            let color = query("color") ?? "#FF3B30"
            let width = Double(query("width") ?? "4.0") ?? 4.0
            let legacyMgr = HSBTVOSConnectionManager.shared()
            
            switch cmd {
            case "next", "page_down":
                HSBModernRemoteBridge.sendCommandNamed("right")
                legacyMgr.sendSimulateAction(.right)
            case "prev", "page_up":
                HSBModernRemoteBridge.sendCommandNamed("left")
                legacyMgr.sendSimulateAction(.left)
            case "draw":
                legacyMgr.sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw,
                    HSBRemotePayloadKeyType: "point",
                    HSBRemotePayloadKeyX: x,
                    HSBRemotePayloadKeyY: y,
                    HSBRemotePayloadKeyColor: color,
                    HSBRemotePayloadKeyWidth: width
                ])
            case "clear":
                legacyMgr.sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw,
                    HSBRemotePayloadKeyType: HSBRemoteDrawTypeClear
                ])
            default:
                break
            }
            return
        }
        
        if host == "app" {
            let bundleId = query("bundleId") ?? query("id") ?? query("bundle") ?? ""
            if !bundleId.isEmpty {
                NotificationCenter.default.post(
                    name: Notification.Name("HSBAppLaunchedNotification"),
                    object: bundleId
                )
            }
        }
    }
}

/// 包装原生 AVCapture 二维码扫描页供 SwiftUI Sheet 调用
public struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    public var onScanPairingURL: (URL) -> Void
    public var onCancel: () -> Void
    
    public init(onScanPairingURL: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.onScanPairingURL = onScanPairingURL
        self.onCancel = onCancel
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public func makeUIViewController(context: Context) -> HSBQRCodeScannerViewController {
        let controller = HSBQRCodeScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: HSBQRCodeScannerViewController, context: Context) {}
    
    public final class Coordinator: NSObject, HSBQRCodeScannerDelegate {
        private let parent: QRCodeScannerRepresentable
        
        init(parent: QRCodeScannerRepresentable) {
            self.parent = parent
        }
        
        public func qrCodeScanner(_ scanner: HSBQRCodeScannerViewController, didScanPairingURL url: URL) {
            parent.onScanPairingURL(url)
        }
        
        public func qrCodeScannerDidCancel(_ scanner: HSBQRCodeScannerViewController) {
            parent.onCancel()
        }
    }
}

/// SwiftUI 内置 Safari 网页浏览包装
public struct ModernSafariView: UIViewControllerRepresentable {
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = UIColor(red: 13/255, green: 14/255, blue: 18/255, alpha: 1)
        vc.preferredControlTintColor = .white
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
