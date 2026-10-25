//
//  ModernRemoteContainerView.swift
//  HSBWatchCompanion
//

import SwiftUI
import Network

public struct ModernRemoteContainerView: View {
    @StateObject private var coordinatorObserver = CoordinatorObservable(coordinator: DualModeRemoteCoordinator.shared)
    
    // 主导航 Tab (糖葫芦双主轴设计：0=遥控 Remote, 1=应用生态 Apps)
    @State private var selectedMainTab: Int = 0
    
    // 遥控器情境微操模式 (0: 系统轮盘, 1: 触控板, 2: IPTV, 3: PDF演讲)
    @State private var selectedControlTab: Int = 0
    @State private var isKeyboardPresented: Bool = false
    @State private var isTrackpadFullScreen: Bool = false
    @State private var showingBrowserGuide: Bool = false
    @State private var showingSystemGuide: Bool = false
    
    private let textInputManager = RemoteTextInputManager()
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    private var isBrowserRemoteVisible: Bool {
        true
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 主内容容器：使用 GeometryReader 获取可用安全区尺寸，严格遵循 Safe Area
            GeometryReader { geometry in
                VStack(spacing: (isTrackpadFullScreen || coordinatorObserver.isTargetMac) ? 2 : (geometry.size.height < 700 ? 6 : 10)) {
                    if !isTrackpadFullScreen && !coordinatorObserver.isTargetMac {
                        // 1. 顶部紧凑双模流线型状态栏 (居中双胶囊排布：大屏通道 + 系统原生通道)
                        ModernRemoteStatusTopBar(
                            coordinatorObserver: coordinatorObserver,
                            showingBrowserGuide: $showingBrowserGuide,
                            showingSystemGuide: $showingSystemGuide
                        )
                        
                        // 2. 主导航 Tab 切换栏 (双主轴架构：【遥控】与【应用生态】)
                        Picker("主导航", selection: $selectedMainTab) {
                            Text("遥控").tag(0)
                            Text("应用生态").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 16)
                    }
                    
                    // 3. 主体内容区：遥控操作台 vs 应用生态网格
                    if selectedMainTab == 0 || isTrackpadFullScreen || coordinatorObserver.isTargetMac {
                        // 遥控操作台 (含情境微操模式切换与交互面板)
                        VStack(spacing: isTrackpadFullScreen ? 2 : (geometry.size.height < 700 ? 6 : 8)) {
                            if !coordinatorObserver.isTargetMac && !isTrackpadFullScreen {
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
                                            if coordinatorObserver.isHSBBrowserReconnecting {
                                                Text("大屏连接中... 点击重新扫码")
                                                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                                    .foregroundColor(.orange)
                                            } else if let nearby = coordinatorObserver.nearbyDiscoveredBrowserTV {
                                                Text("检测到附近【\(nearby)】，点击扫码连接")
                                                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                                    .foregroundColor(.primary)
                                            } else {
                                                Text("尚未连接大屏？点击扫描电视二维码秒级连接")
                                                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                                    .foregroundColor(.primary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.secondary.opacity(0.6))
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                                        )
                                    }
                                    .padding(.horizontal, 16)
                                    .buttonStyle(PlainButtonStyle())
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            
                            
                            remoteScenarioPanel(availableHeight: geometry.size.height)
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
                .padding(.top, isTrackpadFullScreen ? 0 : 4)
                .padding(.bottom, isTrackpadFullScreen ? 2 : 6)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            
            // 键盘输入抽屉
            if isKeyboardPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isKeyboardPresented = false
                    }
                
                VStack {
                    Spacer()
                    ModernKeyboardInputView(
                        isPresented: $isKeyboardPresented,
                        onTextChange: { text, isMarked in
                            if !coordinatorObserver.isTargetMac {
                                textInputManager.handleTextChanged(newText: text, hasMarkedText: isMarked)
                            }
                        },
                        onSubmitText: { committedText in
                            if coordinatorObserver.isTargetMac {
                                DualModeRemoteCoordinator.shared.sendTextInput(text: committedText)
                            } else {
                                textInputManager.handleTextChanged(newText: committedText, hasMarkedText: false)
                                DualModeRemoteCoordinator.shared.sendKeyCommand(key: .enter)
                            }
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
                        if !coordinatorObserver.isNativeConnected {
                            startNativeAppleTVAutoConnect()
                        }
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
        .background(
            Color.auroraBackgroundGradient
                .ignoresSafeArea()
        )
        .animation(.easeInOut(duration: 0.25), value: isKeyboardPresented)
        .animation(.easeInOut(duration: 0.25), value: showingBrowserGuide)
        .animation(.easeInOut(duration: 0.25), value: showingSystemGuide)
        .accentColor(.tanghuluBrandBlue)
        .onAppear {
            setupTextInputManager()
            
            // 若当前目标为 Mac 电脑，严格跳过 Apple TV 与 TV 浏览器大屏通道的自动重连
            guard !coordinatorObserver.isTargetMac && !DualModeRemoteCoordinator.shared.isCurrentTargetMac else {
                return
            }
            
            // 1. 原生 Apple TV 硬件通道自动扫描与连接
            if !coordinatorObserver.isNativeConnected {
                startNativeAppleTVAutoConnect()
            }
            
            // 2. 糖葫芦浏览器专属大屏应用通道尝试重连已配对大屏
            if !coordinatorObserver.isHSBBrowserConnected {
                _ = HSBTVOSConnectionManager.shared().connectToLastPairedTV()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if !coordinatorObserver.isNativeConnected {
                startNativeAppleTVAutoConnect()
            }
            if !coordinatorObserver.isHSBBrowserConnected {
                coordinatorObserver.refreshBrowserChannel()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBToggleRemoteKeyboardNotification"))) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                lightHaptic.impactOccurred()
                isKeyboardPresented.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBTrackpadFullScreenChangedNotification"))) { note in
            if let full = note.userInfo?["isFullScreen"] as? Bool {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isTrackpadFullScreen = full
                }
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
    private func remoteScenarioPanel(availableHeight: CGFloat) -> some View {
        ZStack {
            if coordinatorObserver.isTargetMac {
                // 方案 A：macOS 原生媒体控制中心 (免装软件原生直连)
                MacOSMediaRemoteView(deviceName: coordinatorObserver.targetDeviceName) {
                    DualModeRemoteCoordinator.shared.disconnectAll()
                    NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
                }
            } else if selectedControlTab == 0 {
                // Tab 1: 系统遥控 (Apple TV 原生 D-pad 轮盘与一体化控制岛)
                let dpadSize: CGFloat = availableHeight < 680 ? 200 : 215
                ModernSystemRemoteView(dpadSize: dpadSize)
            } else if selectedControlTab == 1 && isBrowserRemoteVisible {
                // Tab 2: 扩展触控板 (仅在连接真实 hsbtvbrowser 时呈现)
                ModernWebRemoteView()
            } else if selectedControlTab == 2 {
                // Tab 3: IPTV 遥控
                ModernIPTVRemotePanel(isConnected: coordinatorObserver.isHSBBrowserConnected)
            } else {
                // Tab 4: PDF 遥控
                ModernPDFRemotePanel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func setupTextInputManager() {
        textInputManager.delegate = coordinatorObserver
    }
    
    private func startNativeAppleTVAutoConnect() {
        guard !DualModeRemoteCoordinator.shared.nativeClient.isConnected,
              !DualModeRemoteCoordinator.shared.nativeClient.isPairing,
              !DualModeRemoteCoordinator.shared.isCurrentTargetMac else { return }
        
        NSLog("[ModernRemote] Starting Apple TV hardware discovery...")
        HSBAppleTVDiscovery.shared.startScanning { devices in
            guard !DualModeRemoteCoordinator.shared.nativeClient.isConnected,
                  !DualModeRemoteCoordinator.shared.nativeClient.isPairing,
                  !DualModeRemoteCoordinator.shared.isCurrentTargetMac else { return }
            
            // 过滤非 Mac 终端的 Apple TV 硬件设备
            let tvCandidates = devices.filter { !$0.isMacDevice }
            guard !tvCandidates.isEmpty else { return }
            
            // 仅对已有配对凭据的设备发起自动重连
            if let paired = tvCandidates.first(where: {
                DualModeRemoteCoordinator.shared.nativeClient.credentialStore.hasCredentials(for: $0.name)
            }) {
                NSLog("[ModernRemote] Auto-discovered paired Apple TV: %@, reconnecting", paired.name)
                HSBModernRemoteBridge.connectToDiscoveredDevice(paired) { success, err in
                    NSLog("[ModernRemote] Native connection result: success=%d, error=%@", success ? 1 : 0, err ?? "nil")
                }
            }
        }
    }
}
