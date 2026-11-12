//
//  HSBWatchCompanionApp.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI 应用入口与完整生命周期管家（全面替代 AppDelegate、SceneDelegate、main.m 与 Main.storyboard）：
//  1. 承接全部 `hsbremote://` 深度链接与通用路由推送；
//  2. 管理应用前后台切换与硬件直连心跳自愈/Bonjour 重新探测；
//  3. 为整个 NavigationStack 提供沉浸式暗夜样式、Modal 扫码与连接指引弹窗承载。
//

import SwiftUI

@main
public struct HSBWatchCompanionApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = HSBAppRouter.shared
    @StateObject private var homeViewModel = ModernHomeViewModel(isPreviewMock: false)
    
    public init() {
        configureNavigationAppearance()
        HSBModernRemoteBridge.startAutoDiscoveryAndConnect()
    }
    
    public var body: some Scene {
        WindowGroup {
            ZStack {
                NavigationStack(path: $router.path) {
                    ModernHomeView(viewModel: homeViewModel, router: router)
                        .navigationDestination(for: HSBAppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                
                // 全屏独立开屏动画（无导航栏、无任何顶栏操作按钮、纯粹沉浸）
                if homeViewModel.showLaunchAnimation {
                    TanghuluLaunchAnimationView {
                        homeViewModel.finishLaunchAnimation()
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(999)
                }
            }
            .preferredColorScheme(.dark)
            .tint(DuoPalette.hawthornRed)
            .onOpenURL { url in
                router.handleIncomingURL(url)
            }
            .fullScreenCover(isPresented: $router.isQRScannerPresented) {
                QRCodeScannerRepresentable(
                    onScanPairingURL: { scannedURL in
                        router.isQRScannerPresented = false
                        HSBTVOSConnectionManager.shared().connect(toPairingURL: scannedURL)
                    },
                    onCancel: {
                        router.isQRScannerPresented = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(
                isPresented: Binding(
                    get: { router.activeGuideType != nil },
                    set: { if !$0 { router.activeGuideType = nil } }
                )
            ) {
                if let type = router.activeGuideType {
                    ConnectionGuideModalView(
                        type: type,
                        isPresented: Binding(
                            get: { router.activeGuideType != nil },
                            set: { if !$0 { router.activeGuideType = nil } }
                        ),
                        onPrimaryAction: {
                            router.activeGuideType = nil
                            if type == .browser {
                                router.isQRScannerPresented = true
                            } else {
                                HSBModernRemoteBridge.startAutoDiscoveryAndConnect()
                            }
                        },
                        onSecondaryAction: {
                            router.activeGuideType = nil
                            router.push(.remote)
                        }
                    )
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                HSBTVOSConnectionManager.shared().handleAppWillEnterForeground()
                HSBModernRemoteBridge.startAutoDiscoveryAndConnect()
            case .background:
                HSBTVOSConnectionManager.shared().handleAppDidEnterBackground()
            default:
                break
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: HSBAppRoute) -> some View {
        switch route {
        case .remote:
            ModernRemoteContainerView()
                .navigationTitle("智能遥控器")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
                .onAppear {
                    DualModeRemoteCoordinator.shared.startAutoDiscoveryAndConnect()
                }
        case .settings:
            ModernSettingsView { nextRoute in
                router.push(nextRoute)
            }
        case .aiModelCenter:
            ModernLLMModelCenterView {
                router.push(.llmTest)
            }
        case .llmTest:
            ModernLLMTestView {
                router.push(.aiModelCenter)
            }
        case .openSourceLibraries:
            ModernOpenSourceLibrariesView()
        case .contactUs:
            ModernContactUsView()
        case .privacyPolicy:
            ModernPrivacyPolicyView()
        case .about:
            ModernAboutView()
        }
    }
    
    private func configureNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 13/255, green: 14/255, blue: 18/255, alpha: 1)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.06)
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }
}
