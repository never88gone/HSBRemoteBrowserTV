# Project: HSBRemoteBrowserTV (双模现代遥控系统重构)

## Architecture

```
+-----------------------------------------------------------------------------------+
|                               UI / Interaction Layer                              |
|  +--------------------------+  +-------------------------+  +------------------+  |
|  | Modern D-pad & Haptics   |  | Touchpad & Inertia      |  | RemoteTextInput  |  |
|  | (Circle DPadView/Blink)  |  | (1000x1000 Recentering) |  | (Virtual Keyboard|  |
|  |                          |  | (Quad Ease-Out Glide)   |  |  + Atomic Sync)  |  |
|  +--------------------------+  +-------------------------+  +------------------+  |
|                                        │                                          |
|                          Swift / SwiftUI Hosting & Bridge                         |
+----------------------------------------┼------------------------------------------+
                                         │
+----------------------------------------▼------------------------------------------+
|                       DualModeRemoteCoordinator (双模协调器)                       |
|  - 状态机驱动 (HSBConnectionStateMachine: Disconnected/Scanning/Connecting/Ready)    |
|  - 控制命令路由器 (Control Router: Screen Mode vs System Mode)                    |
|  - 自动降级与静默保活 (Auto-failover & Keepalive)                                  |
+--------------------┬────────────────────────────────────────┬---------------------+
                     │                                        │
+--------------------▼--------------------+  +----------------▼--------------------+
|  Screen Channel (专有大屏通道)           |  |  Native Channel (Apple TV 原生通道)  |
|  - Bonjour: _thltv._tcp (56789)         |  |  - Bonjour: _companion-link / _airplay
|  - Transport: Network.framework (AWDL)  |  |  - Port Knocking (3689,7000,49152...)
|  - Protocol: UTF-8 JSON Stream          |  |  - SRP-6a / X25519 / ChaCha20-Poly  |
|  - Parser: Bracket-depth State Machine  |  |  - Companion Link (_hidC, _hidT,    |
|  - Commands: Pan, Tap, Scroll, JS,      |  |    _tiC, _launchApp) & MRP (Mute)   |
|    Zoom, Nav, Media, LLM Translate      |  |  - System Power / Home / Menu / Vol |
+-----------------------------------------+  +-------------------------------------+
```

---

## Code Layout

```
HSBWatchApp/HSBWatchCompanion/
├── Architecture/                     # 混编桥接与全局常量
│   ├── HSBWatchCompanion-Bridging-Header.h
│   └── HSBRemoteConstants.swift
├── Connection/                       # 连接管理与状态机
│   ├── HSBConnectionStateMachine.swift   # 统一连接状态机
│   ├── HSBBonjourDiscovery.swift         # 现代化 Bonjour 设备发现 (AWDL/多网卡)
│   └── HSBJSONMessageParser.swift        # 独立健壮的 JSON 括号平衡拆包粘包解析器
├── Protocols/                        # 双模协议客户端
│   ├── Screen/                           # hsbtvbrowser 专有大屏协议
│   │   ├── HSBBrowserProtocolClient.swift
│   │   └── HSBScreenCommands.swift       # 10 大类大屏控制指令封装
│   ├── Native/                           # Apple TV 原生系统控制协议 (itsytv-core 移植)
│   │   ├── AppleTVNativeClient.swift     # 原生系统通道客户端
│   │   ├── Crypto/                       # SRP-6a, X25519, ChaCha20 加密栈
│   │   ├── Companion/                    # Companion Link 报文与端口敲门唤醒
│   │   └── RTI/                          # RemoteTextInput 0x80 UID BinaryPlist 编码器
│   └── Coordinator/                      # 双模协同调度器
│       └── DualModeRemoteCoordinator.swift
├── ModernUI/                         # 现代交互面板 (SwiftUI)
│   ├── Components/
│   │   ├── ModernDPadView.swift          # 圆形 D-pad、视觉闪烁与触觉震动
│   │   ├── ModernTouchpadView.swift      # 1000x1000 虚拟空间重置与二次缓出惯性滑动
│   │   ├── ModernKeyboardInputView.swift # 软键盘唤起与实时文本输入同步
│   │   └── ModernActionToolbar.swift     # 快捷操作栏与双模状态指示
│   └── ModernRemoteContainerView.swift   # 现代遥控器主容器视图
├── LegacyBridge/                     # 现有业务向下兼容桥接
│   ├── HSBModernRemoteHostingController.swift # UIHostingController 容器桥接
│   └── LegacyModuleCompatibility.m       # LLM/IPTV/视频控制/Watch 透传兼容层
└── Tests/ (or Tests Target)          # 单元测试与协议验证套件
```

---

## Feature Inventory

所有源自 ORIGINAL_REQUEST.md 与调研报告的需求与特性已全量清点并分配至里程碑：

| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Swift-ObjC 混编架构与桥接配置 | 创建 Bridging-Header，打通 Swift 与 Objective-C 双向互调 | M1 | Survey (Explorer 1) |
| 2 | JSON 括号平衡拆包粘包解析器 | 提取并重构 `HSBJSONMessageParser`，支持流式解析、异常截断防死锁 | M1 | R3, Survey (Explorer 3) |
| 3 | 现代 Bonjour 发现增强与下线感知 | 基于 Network.framework 支持 Wi-Fi/AWDL 直连，处理设备下线与自动重连 | M1 | R3, Survey (Explorer 1, 3) |
| 4 | 统一连接状态机管理 | 实现 `HSBConnectionStateMachine`（断开/扫描中/连接中/配对中/已就绪/异常） | M1 | R3, Survey (Explorer 1) |
| 5 | hsbtvbrowser 专有协议全量封装 | 封装 10 大类大屏控制指令（按键、光标5.5x、点击mode 1~6、滚动3.0x、拖拽、导航缩放、JS注入、媒体控制、LLM翻译） | M2 | R1, Survey (Explorer 3) |
| 6 | Apple TV 原生系统通道集成 | 移植 itsytv 原生协议（Companion Link TCP 49152/49153, AirPlay MRP TCP 7000） | M2 | R1, Survey (Explorer 2) |
| 7 | 多端口并发敲门电视唤醒 | 实现 3689, 7000, 49152, 49153 并发端口敲门，唤醒深度睡眠 Apple TV | M2 | R1, Survey (Explorer 2) |
| 8 | 原生认证与安全通信栈 | 实现 SRP-6a 配对、X25519 会话恢复与 ChaCha20-Poly1305 帧对称加密 | M2 | R1, Survey (Explorer 2) |
| 9 | 双模协同调度器 | 实现 `DualModeRemoteCoordinator`，统一分发大屏专有指令与系统级全局指令 | M2 | R1, Survey (Explorer 2) |
| 10 | RTI 软键盘输入与 BinaryPlist 打包 | 实现纯 Swift BinaryPlist (0x80 UID) 编码器，向 Apple TV 发送 `_tiC` 文本操作 | M3 | R2, Survey (Explorer 2) |
| 11 | 原子清空替换与输入法防抖 | 实现 `textToAssert: ""` 原子无闪烁替换，并过滤 `markedRange` 中文拼音脏字符 | M3 | R2, Survey (Explorer 2) |
| 12 | 软键盘调起与降级输入通道 | 提供虚拟键盘组件，支持原生 RTI 同步，以及降级通过专有通道 JS 注入输入 | M3 | R2, Survey (Explorer 1, 3) |
| 13 | 现代圆形 D-pad 视图 | 150pt 圆环 + 75pt 确认键，零延迟原生响应，物理白色高光闪烁动效 | M4 | R2, Survey (Explorer 2) |
| 14 | 物理触感反馈 (Haptics) | 方向键与确认键配置 `UIImpactFeedbackGenerator`，提供细腻触觉震动 | M4 | R2, Survey (Explorer 1, 2) |
| 15 | 1000x1000 触控板无限重置算法 | 虚拟空间越界自动触发边界释放->瞬移置中->重新按下，支持手指单向无限微操 | M4 | R2, Survey (Explorer 2) |
| 16 | 8 阶二次缓出惯性滑动算法 | 抬手时依据脱手速度计算投影距离，60 FPS 步进衰减模拟真实惯性平滑滑动 | M4 | R2, Survey (Explorer 2) |
| 17 | 手势微操增强 (Pinch / Drag) | 补齐双指 Pinch 网页缩放指令与长按拖拽，提升大屏浏览体验 | M4 | R2, Survey (Explorer 1, 3) |
| 18 | 快捷操作栏与双模状态指示 | 顶部/底部快捷栏，包含模式切换按钮、系统电源键、Home/Menu、音量调节 | M4 | R2, Survey (Explorer 1, 2) |
| 19 | UIKit/ObjC 无缝桥接与向下兼容 | 将新遥控视图作为入口桥接至现有工程，完全兼容现有本地 LLM、IPTV、视频播放 | M4 | Acceptance Criteria, Survey (Explorer 1) |
| 20 | 单元测试与协议状态机验证套件 | 构建协议解析、拆包粘包、状态转移、RTI 编码等单元测试集 | M5, Test Track | Acceptance Criteria |
| 21 | E2E 自动化测试套件 (Tiers 1-4) | 独立测试轨构建完整的覆盖式、边界极端、交叉组合及全场景自动化验证 | Test Track | Dual-Track Requirement |
| 22 | 编译完整性与综合验收回归 | 确保 Xcode 完整编译通过，混编无符号冲突，通过 100% E2E 测试并完成审计 | M5 | Acceptance Criteria |

---

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| **M1** | 混编基建与网络容错状态机 | Features #1, #2, #3, #4 (Bridging-Header, HSBJSONMessageParser, HSBBonjourDiscovery, HSBConnectionStateMachine) | none | DONE |
| **M2** | 双模控制通信协议体系 | Features #5, #6, #7, #8, #9 (HSBBrowserProtocolClient, AppleTVNativeClient, Port Knocking, Crypto Stack, DualModeRemoteCoordinator) | M1 | PLANNED |
| **M3** | 实时文本输入同步体系 | Features #10, #11, #12 (RTI BinaryPlist 0x80 UID Encoder, Atomic Clear & IME Guard, Soft Keyboard Sync) | M2 | PLANNED |
| **M4** | 现代 SwiftUI 遥控交互面板与手势系统 | Features #13, #14, #15, #16, #17, #18, #19 (ModernDPadView, Haptics, Touchpad Recentering, Quad Ease-Out Inertia, Toolbar, Legacy Bridge) | M2, M3 | PLANNED |
| **M5** | 综合集成、E2E 测试验收与回归加固 | Features #20, #22 (Xcode 全量编译验证, 混编无冲突, 现有业务回归, E2E 测试 100% 通过, 挑战者与取证审计门禁) | M1, M2, M3, M4, Test Track | PLANNED |
| **TEST** | E2E 测试轨 (独立并行) | Feature #21 (Tiers 1-4 需求驱动测试体系, 测试运行器, 发布 TEST_READY.md) | none | IN_PROGRESS |

---

## Interface Contracts

### 1. `HSBConnectionStateMachine` ↔ UI / 协调器
```swift
public enum HSBConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting(deviceName: String, mode: HSBRemoteMode)
    case pairing(deviceName: String, pinNeeded: Bool)
    case ready(deviceName: String, mode: HSBRemoteMode)
    case failed(error: String)
}

public protocol HSBConnectionStateMachineDelegate: AnyObject {
    func stateMachine(_ sm: HSBConnectionStateMachine, didTransitionTo state: HSBConnectionState)
}
```

### 2. `DualModeRemoteCoordinator` ↔ 上层交互 UI
```swift
public enum HSBRemoteMode {
    case dual           // 双模协同 (默认: 前台大屏高精控制 + 后台系统兜底)
    case screenOnly     // 仅 hsbtvbrowser 专有大屏通道
    case nativeOnly     // 仅 Apple TV 原生系统遥控通道
}

public protocol DualModeRemoteCoordinatorProtocol {
    var currentState: HSBConnectionState { get }
    var currentMode: HSBRemoteMode { get set }
    
    // 导航与 D-pad
    func sendDPad(direction: DPadDirection, action: KeyAction)
    func sendSelect(action: KeyAction)
    
    // 触控板与微操
    func sendCursorPan(dx: CGFloat, dy: CGFloat)
    func sendTap(mode: Int, point: CGPoint?)
    func sendScroll(dx: CGFloat, dy: CGFloat)
    func sendDrag(state: DragState, point: CGPoint)
    func sendZoom(scale: CGFloat)
    
    // 文本输入
    func sendTextInput(text: String, isAtomicReplace: Bool)
    func sendKeyCommand(key: SpecialKey)
    
    // 系统级控制 (Home, Menu, Volume, Power)
    func sendSystemKey(_ key: SystemKey)
    func wakeDevice()
    
    // 专有大屏高级指令
    func sendPageAction(_ action: PageAction)
    func executeJavaScript(_ script: String, completion: ((Result<String, Error>) -> Void)?)
    func sendMediaControl(_ action: MediaAction, value: Double?)
}
```

### 3. `HSBJSONMessageParser` ↔ 传输层 Socket
```swift
public final class HSBJSONMessageParser {
    public init()
    public func append(data: Data) -> [Data]
    public func reset()
}
```
- 输入：任意切片大小的 TCP 原始字节流 `Data`。
- 输出：提取出的一个个完整 JSON 对象 `[Data]`。
- 保证：维护括号深度平衡，忽略有效字符串中的花括号，遇到非法前导垃圾字节立即丢弃恢复，不发生死锁或内存泄漏。

### 4. `LegacyModuleCompatibility` ↔ 现有 ObjC 业务
```objc
@interface HSBModernRemoteBridge : NSObject
+ (UIViewController *)createModernRemoteViewControllerWithHost:(NSString *)host port:(int)port;
+ (void)syncLegacyLLMTranslationWithPrompt:(NSString *)prompt result:(NSString *)result;
@end
```
- 保持原 `HSBRemotePayloadKeyAction` 协议定义不变，现有 IPTV / 本地 LLM / 视频播放控制器继续沿用原有通信分发路径，零侵入无破坏。
