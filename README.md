# 🍬 糖葫芦遥控器 (Tanghulu Smart Remote)

![Platform](https://img.shields.io/badge/Platform-iOS%2017.0+%20%7C%20watchOS%2010.0+%20%7C%20tvOS%2017.0+%20%7C%20macOS%2012.0+-007AFF.svg?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343.svg?style=for-the-badge&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-34C759.svg?style=for-the-badge&logo=swift)
![AI](https://img.shields.io/badge/Edge%20AI-MLX%20LLM%20%7C%20CoreML-8A2BE2.svg?style=for-the-badge&logo=openai)
![License](https://img.shields.io/badge/License-Proprietary-FF9500.svg?style=for-the-badge)

> **专为 Apple TV、macOS 与客厅大屏打造的全场景原生双模无线遥控器与端侧 AI 交互中枢。**  
> 融合 Apple TV 原生系统硬件级控制、macOS 100% 免装软件隔空播放媒体直连、Apple Watch 四大原生微操矩阵、5.5x 阻尼平滑触控板与 Apple Silicon MLX 端侧大模型，带来毫秒级响应、零侵入、极简优雅的跨设备操控体验。

---

## 📸 界面精选 (Screenshots)

| 1. Apple TV 原生遥控 | 2. macOS 隔空播放直控 | 3. 大屏网页高精触控 | 4. 端侧 AI 交互中枢 |
| :---: | :---: | :---: | :---: |
| <img src="screenshot/unified_remote_tab.png" width="200" /> | <img src="screenshot/unified_touchpad.png" width="200" /> | <img src="screenshot/unified_apps_grid.png" width="200" /> | <img src="screenshot/6_ai_assistant.png" width="200" /> |
| **原生系统物理轮盘<br>Companion 协议毫秒直连** | **免装任何客户端软件<br>全局音量与媒体直推** | **阻尼滑动 / 悬浮光标<br>大屏网页高精微操** | **同声传译 / TV 快捷控制<br>100% 离线隐私安全** |

---

## ✨ 核心特性矩阵 (Core Features)

### 1. 🍎 Apple TV 纯原生系统级直连控制
- **Companion 原生协议直连**：基于 Apple 原生 Companion HID 与 MRP (Media Remote Protocol) 协议，采用 SRP-6a 密钥交换与 ChaCha20-Poly1305 端到端硬件级安全加密信道；
- **局域网 mDNS 秒级自动重连**：深度集成 Bonjour 服务自动广播与免密配对自愈，支持多 Apple TV 硬件设备智能过滤与锁定；
- **防按键重发（Anti-Double-Firing）**：独创指令路由幂等校验，彻底解决方向键与选择确认键在复杂局域网环境下的双击误触问题；
- **休眠待机与网络唤醒 (WoL & Wake-from-Sleep)**：支持向休眠状态的 Apple TV 广播 Magic Packet 唤醒包，并自动触发协议通道重建；
- **RTI 实时键盘同步**：内置 Apple Remote Text Input (RTI) 软键盘实时联动，打字与搜索秒级直上大屏。

### 2. 💻 macOS 原生隔空播放媒体控制（方案 1 · 100% 免装软件）
- **真正的系统级零侵入**：依赖 macOS 系统原生自带的 **【隔空播放接收器（AirPlay Receiver / 端口 7000）】**，Mac 端 **0 软件安装、0 守护进程后台驻留、0 特殊辅助功能权限申请**；
- **全局系统硬件音量调节**：支持音量增加、音量减少、平滑无级音量滑块与硬件一键静音/取消静音；
- **全功能媒体播放控制**：支持系统全局播放/暂停、快退 10 秒、快进 10 秒、上一首、下一首曲目无缝切换；
- **真实硬件握手探测**：基于底层 Network.framework TCP 原生握手秒级检测连通性，告别“虚假已连接”，并在未开启时提供优雅的系统设置开启引导；
- **黑胶动态视觉卡片**：集成现代黑胶唱片视觉卡片与多频段动态声波律动条，带来 Apple 原生质感。

### 3. ⌚ Apple Watch 独立手表伴侣 App（四大微操矩阵）
- **D-Pad 触觉轮盘控制**：专为 watchOS 屏幕人体工程学优化的四向触觉反馈轮盘，抬腕即操控客厅大屏；
- **数码表冠平滑无级滚动 (Digital Crown Scroll)**：手腕旋转表冠即可对大屏浏览器、长列表实现像素级细腻滚动与翻页；
- **体感微操飞鼠 (Air Mouse & Motion)**：借助手表内置六轴陀螺仪与加速度计，轻微手腕晃动即可实现空中光标指向与手势快捷操作；
- **全功能媒体与音量中心**：手表端直接独立控制 Apple TV 与 Mac 播放状态和音量，脱离手机独立工作。

### 4. 🌐 客厅大屏浏览器深度整合 (针对 hsbtvbrowser)
- **5.5x 微操阻尼触控板**：内置人体工学加速度曲线算法（Ballistics Acceleration），微移慢推细腻精准，大跨度划动一甩即达全屏；
- **多指手势原生支持**：单指光标平移与轻触左键、双指页面平滑滚轮与右键菜单、三指长按强力点击；
- **客厅应用生态一键触达**：一键无缝唤起大屏网页浏览器、IPTV 电视直播、PDF 演说演示与客厅常用大屏生态。

### 5. 🧠 端侧纯血 MLX 大模型离线矩阵
- **Apple Silicon 原生加速**：深度适配 MLX 离线推理框架（支持 Qwen1.5-0.5B / SmolLM-135M / Gemma-2-2B-IT 等轻量化端侧模型）；
- **客厅智能管家**：支持离线同声传译、多国语言实时翻译、语音遥控脚本生成与离线客厅智能问答，绝不上传云端，确保绝对隐私。

---

## 🏗️ 架构设计与模块说明 (Architecture)

```
HSBWatchApp/
├── HSBWatchCompanion/                   # iOS 伴侣主 App
│   ├── Connection/                      # 网络发现与协议连接
│   │   ├── HSBAppleTVDiscovery.swift    # 局域网 Bonjour/mDNS 设备实时扫描
│   │   └── HSBTVOSConnectionManager.m   # WebSocket / 局域网连接管理器
│   ├── Protocols/                       # 核心协议抽象层
│   │   ├── Coordinator/                 # 双模路由协调器
│   │   │   ├── DualModeRemoteCoordinator.swift # 双模中枢总控
│   │   │   ├── MacMediaCommandDispatcher.swift # macOS 原生 AirPlay 媒体/音量分发
│   │   │   └── RemoteCommandRouter.swift       # 统一按键与手势路由拦截分发
│   │   └── Native/                      # Apple TV 纯原生协议实现
│   │       ├── AppleTVNativeClient.swift       # Companion 协议客户端
│   │       ├── AppleTVWakeService.swift        # 休眠唤醒与 WoL 广播服务
│   │       └── AppleTVProtocol/                # SRP-6a / OPACK / MRP 编解码底层
│   ├── ModernUI/                        # 现代 SwiftUI 响应式界面
│   │   ├── ModernRemoteContainerView.swift     # 遥控器一体化主容器
│   │   └── Components/                         # 核心遥控组件库
│   │       ├── MacOSMediaRemoteView.swift      # macOS 原生隔空播放控制中心
│   │       ├── ModernDPadView.swift            # 极光质感 D-Pad 轮盘
│   │       ├── ModernSystemRemoteView.swift    # Apple TV 系统控制岛
│   │       └── ModernTouchpadView.swift        # 5.5x 阻尼微操触控板
│   └── Features/                        # 业务功能模块 (首页/设置/生态网格)
├── HSBWatchApp Watch App/               # watchOS 原生独立应用
│   ├── ContentView.swift                # 手表端 4 标签页微操容器
│   ├── HSBWatchSessionManager.swift     # WatchConnectivity 手机手表实时双向同步
│   └── Motion/                          # 表冠滚动与体感姿态处理
├── HSBWatchCompanionUITests/            # 物理真机端到端全链路 XCUITest 自动化测试套件
└── fastlane/                            # 自动化构建、验证与 App Store 审核提交流水线
```

---

## ⚡ 快速开始与编译验证 (Getting Started)

### 环境要求
- macOS 14.0+ (推荐 macOS Sonoma / Sequoia)
- Xcode 15.4+ / Xcode 16+
- iOS 17.0+ 部署目标 (iPhone / iPad)
- watchOS 10.0+ 部署目标 (Apple Watch)
- tvOS 17.0+ 目标设备 (Apple TV 4K / HD)

### 1. 编译 iOS 伴侣端
```bash
xcodebuild -project HSBWatchApp/HSBWatchApp.xcodeproj \
           -scheme HSBWatchCompanion \
           -configuration Debug \
           -destination 'generic/platform=iOS' \
           build
```

### 2. 编译 watchOS 独立手表端
```bash
xcodebuild -project HSBWatchApp/HSBWatchApp.xcodeproj \
           -scheme "HSBWatchApp Watch App" \
           -configuration Debug \
           -destination 'generic/platform=watchOS' \
           build
```

### 3. 运行物理真机 UI 自动化测试
```bash
xcodebuild test-without-building \
           -project HSBWatchApp/HSBWatchApp.xcodeproj \
           -scheme HSBWatchCompanion \
           -destination 'id=<YOUR_DEVICE_UDID>' \
           -only-testing:HSBWatchCompanionUITests/HSBWatchCompanionUITests/testMacRemoteControlEndToEnd
```

---

## 🚀 App Store 自动化提交流水线 (Fastlane)

本项目配备高可靠工业级 Fastlane 自动化交付流水线：

```bash
cd HSBWatchApp

# 1. 检查 App Store Connect 版本状态与构建版本列表
bundle exec fastlane check_status

# 2. 校验中英文官方元数据与多尺寸 Apple Watch 截图资产合规性
bundle exec fastlane metadata

# 3. 提交最新已就绪构建至 App Store 官方审核
bundle exec fastlane submit_for_review build_number:<BUILD_NUMBER>
```

---

## 📄 隐私与安全说明 (Privacy & Security)

- **100% 本地局域网通信**：所有遥控指令（Apple TV Companion 报文、macOS 原生隔空播放请求、TV 浏览器控制）均在本地局域网内点对点加密派发，绝不经过任何第三方云端中转服务器；
- **零守护进程依赖**：控制 Mac 时无需在 Mac 上安装任何第三方 Agent 或监听软件，杜绝本地特权漏洞风险；
- **端侧 AI 零隐私泄露**：端侧大模型矩阵完全离线本地运行，不收集用户语音、输入文本或设备日志。

---

## 📜 许可协议 (License)

Copyright © 2026 Tanghulu Team. All rights reserved.
