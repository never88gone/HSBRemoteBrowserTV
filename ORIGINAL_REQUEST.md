# Original User Request

## 2026-09-15T07:05:25Z

结合开源项目 itsytv-macos 的现代遥控交互与 Apple TV 系统通信能力，重构和优化 iOS 端应用 HSBRemoteBrowserTV，使其具备双模控制能力（专有大屏浏览器协议 + Apple TV 原生系统遥控），实现对 tvOS 浏览器应用 hsbtvbrowser 及电视系统的极致控制体验。

Working directory: /Volumes/MacintoshData/Work/MY/Project/Product/HSBRemoteBrowserTV
Integrity mode: development

## Reference Sources & Context

- **开源参考项目**: `/Volumes/MacintoshData/Work/Github/itsytv-macos`（包含精致 D-pad / 手势交互 UI、键盘输入同步 TextInputSession、以及 Git 历史和关联的 Apple TV 原生 Companion/MRP 协议体系）。
- **受控目标应用 (tvOS)**: `/Volumes/MacintoshData/Work/MY/Project/Product/hsbtvbrowser`（基于 Bonjour `_thltv._tcp` 监听并处理 JSON 格式的光标、点击、手势、网页导航、JS 注入、播放控制与翻译指令）。
- **当前开发工程 (iOS/watchOS)**: `/Volumes/MacintoshData/Work/MY/Project/Product/HSBRemoteBrowserTV`（主工程为 `HSBWatchApp.xcworkspace`，目前核心为 Objective-C/UIKit 实现）。

---

## Requirements

### R1. 架构升级与双模控制通信体系 (Dual-Mode Remote Architecture)
构建模块化、清晰解耦的通讯架构，支持双模协同控制：
1. **hsbtvbrowser 专有大屏控制通道**：保持并强化与 tvOS 浏览器现有 Bonjour `_thltv._tcp` JSON 协议的通信，支持光标模拟（MacTap/Pan/Scroll）、网页导航与缩放、JS 执行、媒体播放控制及本地 LLM 翻译通道。
2. **Apple TV 原生系统级控制通道**：参考 itsytv-macos 的成熟机制，引入对 Apple TV 原生 Companion / Remote 协议的支持（配对验证、系统级唤醒、Home/Menu 按键、全局音量调节），在 hsbtvbrowser 未启动或退到后台时仍能系统级唤醒与控制。

### R2. 现代 Swift / SwiftUI 交互面板与手势触控系统 (Modern UI & Gesture System)
借鉴 itsytv-macos 的现代设计哲学，采用 Swift / SwiftUI 构建高性能、触感丝滑的遥控交互组件，并通过桥接机制与现有工程无缝融合：
1. **现代圆形 D-pad 与物理触感按键**：提供高反馈的定向导航键与确认键，带有细腻的视觉状态与触觉反馈（Haptic Feedback）。
2. **高帧率触控板与惯性滑动**：支持大屏光标的微操移动、平滑滚动（Scroll）以及长按拖拽，手势响应敏捷流畅。
3. **实时文本输入组件**：支持直接调起 iOS 软键盘，在输入文字时实时双向/单向同步投递至 tvOS 目标输入框或搜索栏中。

### R3. 连接生命周期与网络容错优化 (Connection Resilience & State Management)
优化网络连接管理层：
1. 增强 Bonjour 设备扫描与自动重连机制，提升多网络接口（Wi-Fi、AWDL）下的发现速度与稳定性。
2. 完善 TCP 字节流拆包/粘包及丢包重发容错处理，保障高频触控数据流的低延迟与长连接稳定性。
3. 提供统一的状态机管理（断开、发现中、配对中、已连接、异常），为 UI 层提供响应式状态驱动。

---

## Acceptance Criteria

### 编译与构建完整性 (Build & Integration)
- [ ] iOS 工程（`HSBWatchApp.xcworkspace` 或对应 Target）能够顺利编译通过，Swift 与 Objective-C 混编桥接正常无符号冲突。
- [ ] 现有功能（包括原有本地 LLM、视频控制、IPTV 等模块）代码与结构不受破坏，保持向下兼容。

### 协议与通信正确性 (Protocol & Communication)
- [ ] 针对 `hsbtvbrowser` 的 JSON 协议指令格式完全匹配 tvOS 端的接收规范（覆盖常用按键、光标模拟、滚动及导航）。
- [ ] 系统级控制模块接口定义明确，能够正确处理配对流程与握手报文序列。
- [ ] 具备单元测试或模拟测试套件，验证关键协议封包/解包、数据帧解析与连接状态机转移逻辑。

### 交互与用户体验 (Interaction & UI)
- [ ] 新版遥控交互视图具备清晰直观的布局，D-pad、手势触控区与快捷操作栏响应灵敏。
- [ ] 支持输入框实时打字事件的捕获与指令分发。
