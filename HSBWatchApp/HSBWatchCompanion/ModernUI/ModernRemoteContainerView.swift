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
                ModernRemoteStatusTopBar(
                    coordinatorObserver: coordinatorObserver,
                    showingBrowserGuide: $showingBrowserGuide,
                    showingSystemGuide: $showingSystemGuide
                )
                
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
                ModernSystemRemoteView()
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
}
