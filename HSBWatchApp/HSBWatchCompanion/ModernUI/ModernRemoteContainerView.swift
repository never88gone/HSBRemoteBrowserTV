//
//  ModernRemoteContainerView.swift
//  HSBWatchCompanion
//

import SwiftUI
import Network

public struct ModernRemoteContainerView: View {
    @ObservedObject private var coordinatorObserver = CoordinatorObservable(coordinator: DualModeRemoteCoordinator.shared)
    
    // 主导航 Tab (沿用 itsytv-macos 经典架构：0=遥控 Remote, 1=应用生态 Apps)
    @State private var selectedMainTab: Int = {
        if UserDefaults.standard.object(forKey: "UITestMainTab") != nil {
            return UserDefaults.standard.integer(forKey: "UITestMainTab")
        }
        return 0
    }()
    
    // 遥控器情境微操模式 (0: 系统轮盘, 1: 触控板, 2: IPTV, 3: PDF演讲)
    @State private var selectedControlTab: Int = {
        #if DEBUG
        if CommandLine.arguments.contains("--iptv-tab") {
            return 2
        }
        #endif
        if UserDefaults.standard.object(forKey: "UITestRemoteTab") != nil {
            return UserDefaults.standard.integer(forKey: "UITestRemoteTab")
        }
        if UserDefaults.standard.bool(forKey: "UITestShowDPad") {
            return 0
        }
        return 0 // 默认首选系统遥控
    }()
    @State private var isKeyboardPresented: Bool = UserDefaults.standard.bool(forKey: "UITestShowKeyboard")
    @State private var showingBrowserGuide: Bool = CommandLine.arguments.contains("--guide-browser")
    @State private var showingSystemGuide: Bool = CommandLine.arguments.contains("--guide-system")
    
    private let textInputManager = RemoteTextInputManager()
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    private var isBrowserRemoteVisible: Bool {
        true
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 糖葫芦深空极光天蓝渐变背景
            Color.auroraBackgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 1. 顶部紧凑双模流线型状态栏 (居中双胶囊排布：大屏通道 + 系统原生通道)
                HStack(spacing: 8) {
                    Spacer()
                    
                    // 1.1 大屏通道状态 (糖葫芦浏览器/专有控制/双指滚动/高级菜单)
                    Button(action: {
                        lightHaptic.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingBrowserGuide = true
                        }
                    }) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(browserStatusColor)
                                .frame(width: 6, height: 6)
                            Text(browserStatusText)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(coordinatorObserver.isHSBBrowserConnected ? .primary : .secondary)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 1.2 Apple TV 系统原生通道状态 (Home/电源/全局控制)
                    Button(action: {
                        lightHaptic.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingSystemGuide = true
                        }
                    }) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(systemStatusColor)
                                .frame(width: 6, height: 6)
                            Text(systemStatusText)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(coordinatorObserver.isNativeConnected ? .primary : .secondary)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                // 2. 主导航 Tab 切换栏 (沿用 itsytv-macos 经典架构：【遥控】与【应用生态】)
                Picker("主导航", selection: $selectedMainTab) {
                    Text("遥控").tag(0)
                    Text("应用生态").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                
                // 3. 主体内容区：遥控操作台 vs 应用生态网格
                if selectedMainTab == 0 {
                    // 遥控操作台 (含情境微操模式切换与交互面板)
                    VStack(spacing: 10) {
                        if !coordinatorObserver.isTargetMac {
                            Picker("遥控形态", selection: $selectedControlTab) {
                                Text("系统").tag(0)
                                Text("触控").tag(1)
                                Text("IPTV").tag(2)
                                Text("演讲").tag(3)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal, 16)
                            
                            // 电视未连接大屏时的轻量引导指引条 (大屏已连通时自动隐退，享受全屏沉浸操作)
                            if !coordinatorObserver.isHSBBrowserConnected {
                                Button(action: {
                                    lightHaptic.impactOccurred()
                                    NotificationCenter.default.post(name: Notification.Name("HSBOpenQRCodeScannerNotification"), object: nil)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "qrcode.viewfinder")
                                            .foregroundColor(.tanghuluBrandBlue)
                                            .font(.system(size: 13))
                                        Text("尚未连接大屏？点击扫描电视二维码秒级连接")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                                    )
                                }
                                .padding(.horizontal, 16)
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        remoteScenarioPanel
                    }
                } else {
                    // 应用生态网格 (一键唤起应用并自动切换对应微操)
                    ModernAppGridView { app in
                        DualModeRemoteCoordinator.shared.launchApp(bundleID: app.bundleID, url: app.url)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedControlTab = app.targetMode
                            selectedMainTab = 0
                        }
                    }
                }
            }
            // 键盘输入抽屉
            if isKeyboardPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isKeyboardPresented = false
                    }
                
                VStack {
                    Spacer()
                    ModernKeyboardInputView(
                        isPresented: $isKeyboardPresented,
                        onTextChange: { text, isMarked in
                            textInputManager.handleTextChanged(newText: text, hasMarkedText: isMarked)
                        },
                        onSubmit: {
                            DualModeRemoteCoordinator.shared.sendKeyCommand(key: .enter)
                            isKeyboardPresented = false
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 大屏应用连接指引弹窗
            if showingBrowserGuide {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingBrowserGuide = false
                        }
                    }
                
                ConnectionGuideModalView(
                    type: .browser,
                    isPresented: $showingBrowserGuide,
                    onPrimaryAction: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingBrowserGuide = false
                        }
                        NotificationCenter.default.post(name: Notification.Name("HSBOpenQRCodeScannerNotification"), object: nil)
                    },
                    onSecondaryAction: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingBrowserGuide = false
                        }
                    }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // 系统通道配对指引弹窗
            if showingSystemGuide {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingSystemGuide = false
                        }
                    }
                
                ConnectionGuideModalView(
                    type: .system,
                    isPresented: $showingSystemGuide,
                    onPrimaryAction: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingSystemGuide = false
                        }
                        NotificationCenter.default.post(name: Notification.Name("HSBOpenQRCodeScannerNotification"), object: nil)
                    },
                    onSecondaryAction: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingSystemGuide = false
                        }
                    }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isKeyboardPresented)
        .animation(.easeInOut(duration: 0.25), value: showingBrowserGuide)
        .animation(.easeInOut(duration: 0.25), value: showingSystemGuide)
        .accentColor(.tanghuluBrandBlue)
        .onAppear {
            setupTextInputManager()
            if !coordinatorObserver.isHSBBrowserConnected {
                if !HSBTVOSConnectionManager.shared().connectToLastPairedTV() {
                    let host = DualModeRemoteCoordinator.shared.nativeClient.currentHost ?? "127.0.0.1"
                    let endpoint = nw_endpoint_create_host(host, "\(HSBRemoteConstants.screenDefaultPort)")
                    let deviceName = HSBTVOSConnectionManager.shared().deviceName ?? "糖葫芦浏览器"
                    HSBTVOSConnectionManager.shared().connect(to: endpoint, deviceName: deviceName)
                    DualModeRemoteCoordinator.shared.screenClient.connect(to: endpoint, deviceName: deviceName)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBToggleRemoteKeyboardNotification"))) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                lightHaptic.impactOccurred()
                isKeyboardPresented.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBShowGuideModalNotification"))) { note in
            if let type = note.userInfo?["type"] as? String {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if type == "browser" {
                        showingBrowserGuide = true
                        showingSystemGuide = false
                    } else if type == "system" {
                        showingBrowserGuide = false
                        showingSystemGuide = true
                    } else if type == "dismiss" {
                        showingBrowserGuide = false
                        showingSystemGuide = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBAppLaunchedNotification"))) { note in
            if let bundleID = note.object as? String {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if bundleID == "com.never88gone.thlbrowser" {
                        selectedControlTab = 1
                        selectedMainTab = 0
                    } else if bundleID == "com.nevergone.huluge.iptv" {
                        selectedControlTab = 2
                        selectedMainTab = 0
                    } else if bundleID == "com.never88gone.thlpdf" {
                        selectedControlTab = 3
                        selectedMainTab = 0
                    } else {
                        selectedControlTab = 0
                        selectedMainTab = 0
                    }
                }
            }
        }
    }
    
    // MARK: - 核心场景交互面板 (系统、触控、IPTV、演讲)
    @ViewBuilder
    private var remoteScenarioPanel: some View {
        ZStack {
            if coordinatorObserver.isTargetMac {
                // 方案 A：macOS 原生媒体控制中心 (免装软件原生直连)
                MacOSMediaRemoteView(deviceName: coordinatorObserver.targetDeviceName)
            } else if selectedControlTab == 0 {
                // Tab 1: 系统遥控 (Apple TV 原生 D-pad 轮盘与一体化控制岛)
                systemRemoteView
            } else if selectedControlTab == 1 && isBrowserRemoteVisible {
                // Tab 2: 扩展触控板 (仅在连接真实 hsbtvbrowser 时呈现)
                webRemoteView
            } else if selectedControlTab == 2 {
                // Tab 3: IPTV 遥控 (经典 CH+/- 换台、音量塔、频道快捷直达与数字选台)
                ModernIPTVControlView(
                    isConnected: coordinatorObserver.isHSBBrowserConnected,
                    onAction: { action in
                        // 1. 优先通过 itsytv 原生系统通道向 Apple TV 发送系统级按键 (纯原生通道传参)
                        switch action {
                        case .channelUp, .up:
                            DualModeRemoteCoordinator.shared.sendDPad(direction: .up, action: .tap)
                        case .channelDown, .down:
                            DualModeRemoteCoordinator.shared.sendDPad(direction: .down, action: .tap)
                        case .left:
                            DualModeRemoteCoordinator.shared.sendDPad(direction: .left, action: .tap)
                        case .right:
                            DualModeRemoteCoordinator.shared.sendDPad(direction: .right, action: .tap)
                        case .select:
                            DualModeRemoteCoordinator.shared.sendSelect(action: .tap)
                        case .volumeUp:
                            DualModeRemoteCoordinator.shared.sendSystemKey(.volumeUp)
                        case .volumeDown:
                            DualModeRemoteCoordinator.shared.sendSystemKey(.volumeDown)
                        case .toggleMute:
                            DualModeRemoteCoordinator.shared.sendSystemKey(.mute)
                        case .play, .pause:
                            DualModeRemoteCoordinator.shared.sendSystemKey(.playPause)
                        case .iptvEpg, .menu:
                            DualModeRemoteCoordinator.shared.sendSystemKey(.menu)
                        default:
                            break
                        }
                        
                        // 2. 兼容第二通道（若已连接）
                        if HSBTVOSConnectionManager.shared().isConnected {
                            HSBTVOSConnectionManager.shared().sendSimulateAction(action)
                        }
                    },
                    onPlayChannel: { name, channelId in
                        // 纯 itsytv 原生通道传参：通过 _launchApp 协议透传播放参数与频道 Scheme
                        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
                        let url = "thliptv://play?id=\(channelId)&name=\(encodedName)"
                        DualModeRemoteCoordinator.shared.launchApp(bundleID: "com.nevergone.huluge.iptv", url: url)
                        if HSBTVOSConnectionManager.shared().isConnected {
                            HSBTVOSConnectionManager.shared().sendPayload([
                                HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvPlayChannel.rawValue,
                                HSBRemotePayloadKeyChannel: name,
                                HSBRemotePayloadKeyId: channelId
                            ])
                        }
                    },
                    onRequestCatalog: { query, group, offset, limit, source, requestId in
                        HSBTVOSConnectionManager.shared().sendPayload([
                            HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvChannels.rawValue,
                            "request": "catalog",
                            "query": query,
                            "group": group,
                            "offset": offset,
                            "limit": limit,
                            "source": source,
                            HSBRemotePayloadKeyRequestId: requestId
                        ])
                    },
                    onFavoriteChange: { channelId, shouldFavorite in
                        HSBTVOSConnectionManager.shared().sendPayload([
                            HSBRemotePayloadKeyAction: shouldFavorite
                                ? HSBRemoteSimulateAction.iptvAddFavorite.rawValue
                                : HSBRemoteSimulateAction.iptvDeleteFavorite.rawValue,
                            HSBRemotePayloadKeyId: channelId
                        ])
                    },
                    onImportSource: { name, url, epgURL, requestId in
                        var payload: [String: Any] = [
                            HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvImportSource.rawValue,
                            HSBRemotePayloadKeyName: name,
                            HSBRemotePayloadKeyUrl: url,
                            HSBRemotePayloadKeyRequestId: requestId
                        ]
                        if let epgURL, !epgURL.isEmpty { payload["epgURL"] = epgURL }
                        HSBTVOSConnectionManager.shared().sendPayload(payload)
                    },
                    onImportEPG: { sourceName, url, requestId in
                        HSBTVOSConnectionManager.shared().sendPayload([
                            HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvImportEPG.rawValue,
                            HSBRemotePayloadKeyUrl: url,
                            "sourceName": sourceName,
                            HSBRemotePayloadKeyRequestId: requestId
                        ])
                    },
                    onImportFile: { type, name, data, requestId in
                        guard !data.isEmpty else { return }
                        let chunkSize = 128 * 1024
                        let chunkCount = (data.count + chunkSize - 1) / chunkSize
                        Task.detached(priority: .userInitiated) {
                            for index in 0..<chunkCount {
                                let lower = index * chunkSize
                                let upper = min(lower + chunkSize, data.count)
                                let chunk = data.subdata(in: lower..<upper).base64EncodedString()
                                HSBTVOSConnectionManager.shared().sendPayload([
                                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvFileChunk.rawValue,
                                    HSBRemotePayloadKeyRequestId: requestId,
                                    "fileType": type,
                                    HSBRemotePayloadKeyName: name,
                                    "index": index,
                                    "chunkCount": chunkCount,
                                    "data": chunk
                                ])
                                try? await Task.sleep(for: .milliseconds(12))
                            }
                        }
                    },
                    onRequestSources: {
                        HSBTVOSConnectionManager.shared().sendSimulateAction(.iptvGetSources)
                    },
                    onDeleteSource: { name in
                        HSBTVOSConnectionManager.shared().sendSimulateAction(.iptvDeleteSource, withParams: [
                            HSBRemotePayloadKeyName: name
                        ])
                    },
                    onRefreshSource: { name, requestId in
                        HSBTVOSConnectionManager.shared().sendSimulateAction(.iptvRefreshSource, withParams: [
                            HSBRemotePayloadKeyName: name,
                            HSBRemotePayloadKeyRequestId: requestId
                        ])
                    },
                    onConfirmSourceRefresh: { requestId, approved in
                        HSBTVOSConnectionManager.shared().sendSimulateAction(.iptvRefreshSource, withParams: [
                            HSBRemotePayloadKeyRequestId: requestId,
                            "confirmRefresh": approved
                        ])
                    },
                    onEPGBindingRequest: { request in
                        var payload: [String: Any] = [
                            HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvImportEPG.rawValue,
                            "operation": request.operation,
                            "sourceName": request.sourceName,
                            HSBRemotePayloadKeyRequestId: request.requestID,
                            "query": request.query,
                            "offset": request.offset,
                            "limit": request.limit
                        ]
                        if let channelID = request.channelID { payload["channelID"] = channelID }
                        if let epgChannelID = request.epgChannelID { payload["epgChannelID"] = epgChannelID }
                        if let mode = request.mode { payload["mode"] = mode }
                        HSBTVOSConnectionManager.shared().sendPayload(payload)
                    },
                    onConfirmPlaylistImport: { requestId, approved, includeEPG in
                        HSBTVOSConnectionManager.shared().sendPayload([
                            HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvImportSource.rawValue,
                            HSBRemotePayloadKeyRequestId: requestId,
                            "confirmImport": approved,
                            "includeEPG": includeEPG
                        ])
                    }
                )
            } else {
                // Tab 4: PDF 遥控 (商务演讲翻页大板、首尾页跳转、激光笔与屏幕涂鸦)
                ModernPDFControlView(
                    onPageChange: { isNext in
                        // 纯 itsytv 原生通道传参：原生 D-Pad 方向键精准翻页
                        DualModeRemoteCoordinator.shared.sendDPad(
                            direction: isNext ? .right : .left,
                            action: .tap
                        )
                        if HSBTVOSConnectionManager.shared().isConnected {
                            HSBTVOSConnectionManager.shared().sendSimulateAction(
                                isNext ? .right : .left
                            )
                        }
                    },
                    onJumpPage: { isFirst in
                        // 纯 itsytv 原生通道传参：原生系统按键 (Home / Menu)
                        DualModeRemoteCoordinator.shared.sendSystemKey(
                            isFirst ? .home : .menu
                        )
                        if HSBTVOSConnectionManager.shared().isConnected {
                            HSBTVOSConnectionManager.shared().sendSimulateAction(
                                isFirst ? .pageHome : .stop
                            )
                        }
                    },
                    onDrawAction: { type, point, color, width in
                        // 纯 itsytv 原生通道传参：原生微移触摸事件
                        DualModeRemoteCoordinator.shared.nativeClient.sendTouchEvent(phase: 2, point: CGPoint(x: point.x, y: point.y))
                        if HSBTVOSConnectionManager.shared().isConnected {
                            HSBTVOSConnectionManager.shared().sendPayload([
                                HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw.rawValue,
                                HSBRemotePayloadKeyType: type,
                                HSBRemotePayloadKeyX: Double(point.x),
                                HSBRemotePayloadKeyY: Double(point.y),
                                HSBRemotePayloadKeyColor: color,
                                HSBRemotePayloadKeyWidth: Double(width)
                            ])
                        }
                    },
                    onClear: {
                        if HSBTVOSConnectionManager.shared().isConnected {
                            HSBTVOSConnectionManager.shared().sendPayload([
                                HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw.rawValue,
                                HSBRemotePayloadKeyType: HSBRemoteDrawTypeClear
                            ])
                        }
                    },
                    onUndo: {
                        if HSBTVOSConnectionManager.shared().isConnected {
                            HSBTVOSConnectionManager.shared().sendPayload([
                                HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw.rawValue,
                                HSBRemotePayloadKeyType: HSBRemoteDrawTypeUndo
                            ])
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Tab 1: 系统遥控视图 (黄金比例与一体化控制岛)
    private var systemRemoteView: some View {
        VStack(spacing: 0) {
            // 上半部微缓冲 (收紧顶部间隙，让轮盘自然承接Tab栏)
            Spacer(minLength: 6)
                .frame(maxHeight: 14)
            
            // 现代 270pt 质感 D-pad 轮盘 (居于单手握持最佳操控中轴)
            ModernDPadView(
                size: 270,
                onDirection: { dir, action in
                    DualModeRemoteCoordinator.shared.sendDPad(direction: dir, action: action)
                },
                onSelect: { action in
                    DualModeRemoteCoordinator.shared.sendSelect(action: action)
                }
            )
            
            // 轮盘与控制岛之间的黄金呼吸间隙
            Spacer(minLength: 16)
                .frame(maxHeight: 32)
            
            // 下半屏：高质感一体化控制岛 (Control Island)
            VStack(spacing: 16) {
                // 1. 媒体播放核心控制行 (快退 10 秒 / 播放暂停 / 快进 10 秒)
                HStack(spacing: 12) {
                    mediaControlButton(icon: "gobackward.10", title: "快退 10s") {
                        DualModeRemoteCoordinator.shared.sendDPad(direction: .left, action: .tap)
                    }
                    
                    mediaControlButton(icon: "playpause.fill", title: "播放 / 暂停", isPrimary: true) {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.playPause)
                    }
                    
                    mediaControlButton(icon: "goforward.10", title: "快进 10s") {
                        DualModeRemoteCoordinator.shared.sendDPad(direction: .right, action: .tap)
                    }
                }
                
                // 2. 系统核心功能行 (桌面, 返回, 静音, 待机)
                HStack(spacing: 16) {
                    systemIslandRoundButton(icon: "house.fill", label: "桌面") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.home)
                    }
                    systemIslandRoundButton(icon: "arrow.uturn.backward", label: "返回") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.menu)
                    }
                    systemIslandRoundButton(icon: "speaker.slash.fill", label: "静音") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.mute)
                    }
                    systemIslandRoundButton(icon: "power", label: "待机") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.power)
                    }
                }
                
                // 3. 硬件音量调节行
                HStack(spacing: 12) {
                    Button {
                        lightHaptic.impactOccurred()
                        DualModeRemoteCoordinator.shared.sendSystemKey(.volumeDown)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.minus.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("音量 -")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        lightHaptic.impactOccurred()
                        DualModeRemoteCoordinator.shared.sendSystemKey(.volumeUp)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.plus.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("音量 +")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            
            // 底部自然贴合安全区
            Spacer(minLength: 12)
        }
    }
    
    private func mediaControlButton(icon: String, title: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            lightHaptic.impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 16 : 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: isPrimary ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isPrimary ? Color.accentColor.opacity(0.2) : Color(UIColor.tertiarySystemBackground))
            .foregroundColor(isPrimary ? Color.accentColor : .primary)
            .cornerRadius(11)
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isPrimary ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private func systemIslandRoundButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Tab 2: 网页遥控视图
    private var webRemoteView: some View {
        VStack(spacing: 14) {
            // 触控微操板
            ModernTouchpadView(
                onPan: { dx, dy in
                    DualModeRemoteCoordinator.shared.sendCursorPan(dx: dx, dy: dy)
                },
                onTap: { mode, pt in
                    DualModeRemoteCoordinator.shared.sendTap(mode: mode, point: pt)
                },
                onScroll: { dx, dy in
                    DualModeRemoteCoordinator.shared.sendScroll(dx: dx, dy: dy)
                },
                onDrag: { state, dx, dy in
                    DualModeRemoteCoordinator.shared.sendDrag(state: state, dx: dx, dy: dy)
                },
                onZoom: { scale in
                    DualModeRemoteCoordinator.shared.sendZoom(scale: scale)
                }
            )
            .padding(.horizontal, 16)
            
            // 网页悬浮磨砂操作岛 (后退、前进、刷新、主页、放大)
            HStack(spacing: 8) {
                webNavButton(icon: "chevron.backward", title: "后退") {
                    DualModeRemoteCoordinator.shared.sendPageAction(.back)
                }
                webNavButton(icon: "chevron.forward", title: "前进") {
                    DualModeRemoteCoordinator.shared.sendPageAction(.forward)
                }
                webNavButton(icon: "arrow.clockwise", title: "刷新") {
                    DualModeRemoteCoordinator.shared.sendPageAction(.reload)
                }
                webNavButton(icon: "house", title: "主页") {
                    DualModeRemoteCoordinator.shared.sendPageAction(.home)
                }
                webNavButton(icon: "plus.magnifyingglass", title: "放大") {
                    DualModeRemoteCoordinator.shared.sendZoom(scale: 1.25)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    @ViewBuilder
    private func systemRoundButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func webNavButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(UIColor.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func setupTextInputManager() {
        textInputManager.delegate = coordinatorObserver
    }
    
    // MARK: - Dual Channel Status Displays (大屏通道 & 系统原生通道)
    private var browserStatusColor: Color {
        if coordinatorObserver.isTargetMac || coordinatorObserver.isHSBBrowserConnected {
            return .tanghuluBrandBlue
        } else {
            return .gray
        }
    }
    
    private var browserStatusText: String {
        if coordinatorObserver.isTargetMac {
            return "大屏: 已连接"
        }
        if coordinatorObserver.isHSBBrowserConnected {
            let name = coordinatorObserver.browserDeviceName.isEmpty ? "已连接" : coordinatorObserver.browserDeviceName
            return "大屏: \(name)"
        } else {
            return "大屏: 未连接"
        }
    }
    
    private var systemStatusColor: Color {
        if coordinatorObserver.isTargetMac || coordinatorObserver.isNativeConnected {
            return .tanghuluBrandBlue
        }
        if coordinatorObserver.isHSBBrowserConnected {
            return .tanghuluBrandBlue.opacity(0.8)
        }
        switch coordinatorObserver.state {
        case .ready: return .tanghuluBrandBlue
        case .connecting, .pairing: return .orange
        case .scanning: return .tanghuluBrandBlue
        case .failed: return .orange
        case .disconnected: return .gray
        }
    }
    
    private var systemStatusText: String {
        if coordinatorObserver.isTargetMac {
            return "系统: 已连接"
        }
        if coordinatorObserver.isNativeConnected {
            return "系统: 已连接"
        }
        if coordinatorObserver.isHSBBrowserConnected {
            return "系统: 协同就绪"
        }
        switch coordinatorObserver.state {
        case .ready(let name, _):
            return "系统: \(name)"
        case .connecting:
            return "系统: 连接中..."
        case .pairing:
            return "系统: 配对中..."
        case .scanning:
            return "系统: 扫描中..."
        case .failed(let err):
            if err.contains("待机") {
                return "系统: 待机唤醒"
            }
            return "系统: 未连接"
        case .disconnected:
            return "系统: 未连接"
        }
    }
}

// MARK: - Observer Class for Coordinator State
@MainActor
private final class CoordinatorObservable: ObservableObject, DualModeRemoteCoordinatorDelegate, RemoteTextInputManagerDelegate {
    @Published var state: HSBConnectionState = .disconnected
    @Published var isHSBBrowserConnected: Bool = false
    @Published var browserDeviceName: String = ""
    @Published var isNativeConnected: Bool = false
    @Published var isTargetMac: Bool = false
    @Published var targetDeviceName: String = "Mac"
    private let coordinator: DualModeRemoteCoordinator
    
    init(coordinator: DualModeRemoteCoordinator) {
        self.coordinator = coordinator
        self.state = coordinator.currentState
        let legacyMgr = HSBTVOSConnectionManager.shared()
        self.isHSBBrowserConnected = legacyMgr.isConnected || coordinator.screenClient.isConnected
        self.browserDeviceName = legacyMgr.deviceName ?? ""
        self.isNativeConnected = coordinator.nativeClient.isConnected
        self.isTargetMac = coordinator.isCurrentTargetMac || CommandLine.arguments.contains("--test-mac-media")
        self.targetDeviceName = coordinator.currentTargetDeviceName.isEmpty ? "Mac" : coordinator.currentTargetDeviceName
        coordinator.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTVOSConnectionNotification(_:)),
            name: .HSBTVOSConnectionState,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleTVOSConnectionNotification(_ note: Notification) {
        DispatchQueue.main.async {
            let legacyMgr = HSBTVOSConnectionManager.shared()
            self.isHSBBrowserConnected = legacyMgr.isConnected || self.coordinator.screenClient.isConnected
            self.browserDeviceName = legacyMgr.deviceName ?? ""
        }
    }
    
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didChangeState state: HSBConnectionState) {
        DispatchQueue.main.async {
            self.state = state
            let legacyMgr = HSBTVOSConnectionManager.shared()
            self.isHSBBrowserConnected = legacyMgr.isConnected || coordinator.screenClient.isConnected
            self.browserDeviceName = legacyMgr.deviceName ?? ""
            self.isNativeConnected = coordinator.nativeClient.isConnected
            self.isTargetMac = coordinator.isCurrentTargetMac || CommandLine.arguments.contains("--test-mac-media")
            if !coordinator.currentTargetDeviceName.isEmpty {
                self.targetDeviceName = coordinator.currentTargetDeviceName
            }
        }
    }
    
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didReceiveScreenMessage message: [String: Any]) {
        // 接收消息处理
    }
    
    func textInputManager(_ manager: RemoteTextInputManager, didProduceRTIPayload data: Data) {
        // Native RTI 同步
    }
    
    func textInputManager(_ manager: RemoteTextInputManager, didFallbackToScript script: String) {
        coordinator.executeJavaScript(script, completion: nil)
    }
}

extension Color {
    /// 糖葫芦官方新版图标同源朱砂红 (#E02438)
    public static let tanghuluAccentRed = Color(red: 224.0 / 255.0, green: 36.0 / 255.0, blue: 56.0 / 255.0)
    /// 兼容旧命名，映射至新版朱砂红
    public static let tanghuluBrandBlue = tanghuluAccentRed
    
    /// 深炭黑沉浸背景渐变
    public static let auroraBackgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 37.0 / 255.0, green: 38.0 / 255.0, blue: 43.0 / 255.0),
            Color(red: 28.0 / 255.0, green: 29.0 / 255.0, blue: 33.0 / 255.0),
            Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 22.0 / 255.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 连接指引模态弹窗 (涵盖大屏应用启动与 Apple TV 系统原生配对引导)
public enum ConnectionGuideType {
    case browser
    case system
}

public struct ConnectionGuideModalView: View {
    public let type: ConnectionGuideType
    @Binding public var isPresented: Bool
    public var onPrimaryAction: () -> Void
    public var onSecondaryAction: () -> Void
    
    public init(
        type: ConnectionGuideType,
        isPresented: Binding<Bool>,
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void
    ) {
        self.type = type
        self._isPresented = isPresented
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部关闭与把手区
            HStack {
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // 核心图标与标题
            VStack(spacing: 8) {
                Image(systemName: type == .browser ? "tv.and.mediabox" : "appletvremote.gen4.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.tanghuluBrandBlue)
                    .padding(.bottom, 4)
                
                Text(type == .browser ? "糖葫芦浏览器专属大屏控制" : " Apple TV 原生系统遥控配对")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(type == .browser ? "扫描电视专属二维码，开启网页光标微操与同传" : "支持全局控制 tvOS 桌面、音量、系统按键与各大 App")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
            
            // 步骤内容卡片列表
            VStack(spacing: 12) {
                if type == .browser {
                    GuideStepRow(
                        stepNumber: 1,
                        title: "打开电视端【糖葫芦浏览器】",
                        detail: "使用电视遥控器在 Apple TV 桌面打开应用，进入主界面。"
                    )
                    GuideStepRow(
                        stepNumber: 2,
                        title: "调出屏幕右上角配对二维码",
                        detail: "点击电视首页右上角的【📱 手机遥控配对】按钮呈现专属二维码。"
                    )
                    GuideStepRow(
                        stepNumber: 3,
                        title: "手机对准扫码秒连",
                        detail: "点击下方【扫描电视二维码】，对准大屏即可极速建立网页光标控制通道。"
                    )
                } else {
                    GuideStepRow(
                        stepNumber: 1,
                        title: "保持同一家庭 Wi-Fi 网络",
                        detail: "确保 iPhone 与 Apple TV 连接在同一局域网 Wi-Fi 下。"
                    )
                    GuideStepRow(
                        stepNumber: 2,
                        title: "查看电视屏幕上的 4 位 PIN 码",
                        detail: "发起连接后，Apple TV 系统屏幕正中央将弹出 4 位数字安全验证码。"
                    )
                    GuideStepRow(
                        stepNumber: 3,
                        title: "手机输入 PIN 码即可永久绑定",
                        detail: "在手机弹出的输入框中输入该 PIN 码，一次配对后续永久自动免密连接。"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            // 操作按钮区
            VStack(spacing: 10) {
                Button(action: onPrimaryAction) {
                    HStack {
                        Image(systemName: type == .browser ? "qrcode.viewfinder" : "link.badge.plus")
                        Text(type == .browser ? "扫描电视二维码" : "连接并等待输入 PIN 码")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.tanghuluBrandBlue)
                    .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onSecondaryAction) {
                    Text(type == .browser ? "暂不扫码" : "我知道了")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - 引导步骤行组件
public struct GuideStepRow: View {
    public let stepNumber: Int
    public let title: String
    public let detail: String
    
    public init(stepNumber: Int, title: String, detail: String) {
        self.stepNumber = stepNumber
        self.title = title
        self.detail = detail
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.tanghuluBrandBlue.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text("\(stepNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.tanghuluBrandBlue)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

