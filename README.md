# 🍬 糖葫芦遥控器 (Tanghulu Smart Remote & Browser)

![Platform](https://img.shields.io/badge/Platform-iOS%2017.0+%20%7C%20watchOS%2010.0+%20%7C%20tvOS%2017.0+-007AFF.svg?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343.svg?style=for-the-badge&logo=swift)
![AI](https://img.shields.io/badge/Edge%20AI-MLX%20LLM%20%7C%20CoreML-8A2BE2.svg?style=for-the-badge&logo=openai)
![Version](https://img.shields.io/badge/Version-1.0.0-34C759.svg?style=for-the-badge)
![License](https://img.shields.io/badge/License-Proprietary-gray.svg?style=for-the-badge)

> **“融合端侧前沿大模型与 Apple 极致生态的客厅大屏交互革命。”**
>
> 糖葫芦遥控器（`HSBRemoteBrowserTV` / `HSBWatchCompanion`）是一款专为 **Apple TV** 与客厅智能大屏量身定制的**双模无线遥控与端侧 AI 交互中心**。它不仅打破了传统实体遥控器的单一物理按键限制，更基于 **Apple Silicon MLX 纯血端侧大模型矩阵**、**5.5x 微操触控板**、**RTI 实时软键盘同步** 与 **大屏 WebKit 深度控制通道**，为用户带来影音娱乐、网页浏览、文档演说与智能管家的极致交互体验。

---

## 📸 精选界面展示 (Screenshots)

### 🌐 板块一：电视遥控中枢与浏览器深度交互 (TV Remote Hub & Browser Interaction)
| 1. 局域网大屏设备发现与配对 | 2. 遥控中枢：浏览器控制与 JS 脚本 | 3. 遥控中枢：视频控制与播放倍速 | 4. 统一设置中枢与端侧模型入口 |
| :---: | :---: | :---: | :---: |
| <img src="screenshot/1_device_discovery.png" width="220" /> | <img src="screenshot/2_browser_control.png" width="220" /> | <img src="screenshot/3_video_control.png" width="220" /> | <img src="screenshot/4_settings_hub.png" width="220" /> |
| **Bonjour 无感直连 / 状态监听** | **JS 快捷芯片 / 全屏触控 / URL投送 / AI助手** | **0.5x~2.0x 倍速 / 10s快进退 / 音量调控** | **端侧模型中心 / 多语言与系统设置** |

### 🤖 板块二：客厅原生生态与端侧 AI 矩阵 (System Remote & Edge AI)
| 5. 系统级双模遥控 | 6. IPTV 直播流控制 | 7. PDF 大屏演说投屏 |
| :---: | :---: | :---: |
| <img src="HSBWatchApp/fastlane/screenshots/zh-Hans/1_system_remote.png" width="260" /> | <img src="HSBWatchApp/fastlane/screenshots/zh-Hans/2_iptv_remote.png" width="260" /> | <img src="HSBWatchApp/fastlane/screenshots/zh-Hans/3_pdf_presentation.png" width="260" /> |
| **8. AI 模型管理中心** | **9. AI 智能助手调用** | **10. 糖葫芦全生态矩阵** |
| <img src="HSBWatchApp/fastlane/screenshots/zh-Hans/5_ai_model_center.png" width="260" /> | <img src="HSBWatchApp/fastlane/screenshots/zh-Hans/6_ai_assistant.png" width="260" /> | <img src="HSBWatchApp/fastlane/screenshots/zh-Hans/4_ecosystem_about.png" width="260" /> |


---

## 🔥 核心特性与技术亮点 (Core Features)

### 🔀 1. 双模无线遥控架构 (Dual-Mode Remote Architecture)
独创双通道协同遥控体系，兼顾系统级实体控制与大屏网页深度交互：
* **大屏专有浏览器通道 (Screen Channel)**：
  - 与 tvOS 端「hsbtvbrowser」大屏浏览器基于 Bonjour `_thltv._tcp` 专有协议长链接通信；
  - **5.5x 超高灵敏度微操触控板**：内置 1000×1000 虚拟空间坐标重置算法，手指滑动无死角；
  - **丝滑惯性滑动**：采用 8 阶二次缓出 (Quad Ease-Out) 60FPS 衰减曲线，呈现丝滑自然的阻尼滚动手感；
  - **大屏 WebKit 深度控制**：支持原生 DOM 元素拾取、精准点击、长按选区拖拽与动态 JavaScript 脚本实时注入。
* **Apple TV 原生系统通道 (Native Channel)**：
  - 针对 tvOS 操作系统级底座，支持 Bonjour 并发扫描与端口多路唤醒 (3689 / 7000 / 49152)；
  - 提供系统级 **Home 键**、**Menu 返回键**、**设备休眠/唤醒**、以及机身侧边实体物理音量键双向静默联动；
  - 即便 tvOS 浏览器未开启或置于后台，依然能作为全功能 Apple TV 原生遥控器使用。

---

### 🤖 2. 端侧纯血 MLX 大模型矩阵 (On-Device Edge AI Matrix)
创新性地将 iPhone 打造为“客厅边缘 AI 推理算力中心”，深度整合 `mlx-swift` 与 Apple Silicon 神经引擎，实现 100% 本地离线运行，零云端隐私泄露风险：

| 官方推荐模型 | 仓库标识 (Repo ID) | 模型定位 | 核心业务场景 |
| :--- | :--- | :---: | :--- |
| **Qwen1.5-0.5B (官方推荐)** | `mlx-community/Qwen1.5-0.5B-Chat-4bit` | 轻量多语言通识 | **场景 1：同声传译**（中英日韩多语言即时互译与字幕校对） |
| **SmolLM-135M (极速体验)** | `mlx-community/SmolLM-135M-Instruct-4bit` | 毫秒级极速响应 | **场景 2：电视控制 JS 脚本生成**（全屏、夜间模式、去广告、样式重排） |
| **Gemma-2-2B-IT (深度推理)** | `mlx-community/gemma-2-2b-it-4bit` | Google 深度指令遵循 | **场景 3：客厅智能管家**（Apple TV 连接排障、HDMI-CEC 联动、客厅百科问答） |

* **完整生命周期管理**：支持一键多源断点下载、国内镜像加速通道 (`hf-mirror.com`)、高精度百分比进度条流转、暂停/恢复；
* **错误自愈与死锁防护**：底层遇到弱网或中断发出的 `-1.0` 错误信号，毫秒级转入 `Failed` 状态并重置进度，解除假死，支持随时一键重试；
* **物理缓存安全清理**：支持左滑清除本地沙盒 Safetensors 权重文件并安全解绑反激活，释放宝贵的手机存储空间；
* **自定义大模型 API 模式**：兼容 OpenAI / DeepSeek / Ollama（局域网私有部署）/ LM Studio 标准 `/chat/completions` 协议，无需下载大体积权重即可秒连私有算力；
* **三级容错无缝兜底**：物理大模型未激活、显存不足或处于模拟器环境时，**100% 自动降级至内置离线端侧智能引擎**，保证零白屏、零报错、秒级流式打字输出。

---

### ⌨️ 3. RTI 实时软键盘大屏输入同步 (Real-Time Text Input)
* **大屏输入痛点终结者**：告别使用传统遥控器在电视屏幕上逐字移动光标输入的痛苦体验；
* **实时键盘流**：手机端直接调起系统级软键盘，拼音、英文、符号输入即时单向/双向推送到 Apple TV 当前聚焦的输入框或搜索栏中。

---

### 📺 4. 客厅流媒体与演说全生态矩阵 (Tanghulu Ecosystem Matrix)
* **🌐 糖葫芦浏览器 (Tanghulu Browser)**：电视大屏 WebKit 网页无障碍浏览，支持广告智能过滤与夜间护眼配色；
* **📺 IPTV 直播流多频道路由**：提供客厅电视直播流频道快捷切换、电子节目单 (EPG) 浏览与媒体全屏控制；
* **📄 糖葫芦 PDF 大屏演说神器**：会议与课堂汇报利器，手机化身为激光笔与无线翻页器，支持极速跳页与大屏批注；
* **⌚ watchOS 独立随身主控**：配备独立的 Apple Watch 应用，抬腕即可调控电视播放、音量与导航。

---

### 🎛️ 5. 四大专属遥控场景常驻常开 (Four Specialized Remote Scenarios)
顶部 Segment 选项卡支持随时一键无缝自由切换，未连接外置大屏时亦支持离线微操与体验：
* **【系统】(System Remote)**：配备 270pt 黄金比例 Apple TV 原生质感 D-pad 轮盘与一体化控制岛（快退10s / 播放暂停 / 快进10s / 桌面 / 返回 / 静音 / 待机 / 硬件音量+/-）；
* **【触控】(Browser Touchpad)**：专为大屏 WebKit 浏览器定制的 5.5x 微操触控板、网页悬浮操作岛（后退/前进/刷新/主页/放大）与 RTI 实时软键盘同步抽屉；
* **【IPTV】(IPTV Live Stream)**：客厅电视直播流快捷换台塔（CH+/-）、数字键快速输入选台与音量控制；
* **【演讲】(PDF Presentation)**：商务演讲幻灯片极速翻页大板、首尾页跳转、激光笔指向与屏幕荧光笔涂鸦批注。

---

## 🌐 手机与 TV 浏览器交互操作全景指南 (Browser Interaction Guide)

糖葫芦遥控器与「糖葫芦大屏浏览器 (hsbtvbrowser)」紧密协同，彻底终结了智能电视使用传统物理按键遥控器浏览网页与操作流媒体的灾难性体验。以下为您提供完整的交互操作全景指南：

---

### 📡 1. 局域网无感设备发现与自动配对 (Zero-Config Bonjour Discovery)
<p align="center">
  <img src="screenshot/1_device_discovery.png" width="320" alt="局域网设备发现与连接" />
</p>

* **工作原理**：基于苹果专有 Bonjour 局域网多播协议（服务类型：`_thltv._tcp`），手机与大屏无需手动配置 IP 地址或扫码配对；
* **操作步骤**：
  1. 确保 iPhone 与运行「糖葫芦浏览器」的 Apple TV 置于同一 Wi-Fi 网络下；
  2. 打开手机端，应用自动启动后台多路端口（3689 / 7000 / 49152）静默扫描；
  3. 在「设备发现」列表轻触 **“糖葫芦浏览器”** 单元，系统即刻建立安全稳定的 TCP 长链接通道；
  4. 手机端连接指示徽标点亮为绿色常亮，瞬间解锁全屏大触控板与快捷操作中心。

---

### 🖐️ 2. 电视遥控中枢：浏览器控制与常用 JS 脚本芯片 (Browser Remote & JS Chips)
<p align="center">
  <img src="screenshot/2_browser_control.png" width="320" alt="电视遥控中枢 - 浏览器控制模式" />
</p>

通过首页点击已发现的大屏设备，即可进入全新改版的**「电视遥控中枢」**，切换至【浏览器】模式，尽享一体化大屏冲浪体验：
* **常用快捷 JS 芯片 (Quick Action Chips)**：顶部横向滚动栏常驻常用脚本，轻触即刻通过 TCP 专有长连接秒级注入大屏 WebKit：
  - `抖音_全屏`：消除网页版侧边与上下边框，短视频直接全屏无黑边沉浸呈现；
  - `抖音_启动跳转`：自动跳过开屏弹窗与引导页，直达视频推荐流；
  - `抖音_自动登录`：协助跨端完成安全鉴权；
  - `抖音_连播点击`：开启大屏短视频无缝自动连播体验；
* **5.5x 微操触控板 (5.5x Precision Trackpad)**：
  - 独创 **1000×1000 相对虚拟空间坐标重置算法** 与 **8 阶二次缓出 60FPS 衰减阻尼**，操控大屏虚拟光标顺滑精准；
  - **手势体系**：单指平移光标、双指上下阻尼滚动、双指轻点模拟鼠标左键、三指轻点唤出上下文菜单、四指按下锁定拖动；
* **一键 URL 地址栏投送 (Instant URL Bar)**：手机端直接输入或粘贴网址，轻触蓝色箭头按钮瞬间推送至 Apple TV 大屏加载；
* **流媒体播放器即时控制 (Player Control)**：
  - 提供「打开播放器」与「关闭播放器」专属按键；
  - 配备横向高精度播放进度/音量调节滑块，支持毫秒级精准拉动；
* **AI 智能助手悬浮岛 (Edge AI Floating Island)**：
  - 右下角常驻紫色发光 AI 魔法按钮，轻触即可唤起端侧纯血 MLX 大模型；
  - 支持自然语言对话、网页脚本实时生成（如夜间护眼模式、字体放大、广告过滤），并支持一键将生成脚本下发注入大屏；
* **底部 Web 导航控制坞 (Navigation Dock)**：
  - 后退 (`<`) / 前进 (`>`) / 刷新 (`⟳`) / 主页 (`⌂`) / 脚本管理 (`✎`)。

---

### 🎬 3. 电视遥控中枢：视频控制与播放速率调节 (Video Remote & Playback Rate)
<p align="center">
  <img src="screenshot/3_video_control.png" width="320" alt="电视遥控中枢 - 视频控制模式" />
</p>

在「电视遥控中枢」顶部轻触【视频】选项卡，即可无缝切换为专业级大屏影音播放调控面板：
* **0.5x ~ 2.0x 六档极速倍速调节**：预置 `0.5x`、`0.75x`、`1.0x`、`1.25x`、`1.5x`、`2.0x` 快捷倍速切换，适应不同观影与学习节奏；
* **10 秒高精度快进快退**：大尺寸实体质感按键，毫秒级响应，轻松跳过片头广告或重看精彩镜头；
* **大屏音量实时滑块**：可视化横向滑块与当前电视音量双向同步联动；
* **双模平滑切换**：无需退出当前页面，在【视频】与【浏览器】之间一键无感流转，兼得影音享受与深度交互。

---

### ⚙️ 4. 统一设置中枢与端侧 AI 模型入口 (Settings & Edge AI Hub)
<p align="center">
  <img src="screenshot/4_settings_hub.png" width="320" alt="统一设置中枢与模型中心" />
</p>

* **模块化管理**：轻触首页右上角齿轮图标，即可呼出全新现代设计的设置中枢；
* **AI 核心直达**：快捷进入「AI 模型中心」管理端侧物理大模型下载与权重沙盒，或进入「AI 智能助手」执行同声传译与大屏控制脚本生成；
* **多语言与生态**：支持中英文翻译源/目标语言切换、第三方开源协议查看与关于糖葫芦生态矩阵。

---

## 🏛️ 核心系统架构图 (Architecture)

```mermaid
flowchart TD
    subgraph Client["📱 iOS 配套端 (HSBWatchCompanion)"]
        UI["Modern UI 面板\n(D-Pad / 触控板 / 键盘 / AI中心)"]
        Coordinator["DualModeRemoteCoordinator\n(双模通讯协调器)"]
        LLMManager["HSBLocalLLMManager\n(AI 引擎三级调度中心)"]
    end

    subgraph Channels["📡 双模无线通信通道"]
        ScreenCh["大屏专有通道 (Screen Channel)\nBonjour _thltv._tcp JSON / 5.5x 微操"]
        NativeCh["Apple TV 原生通道 (Native Channel)\nCompanion / MRP / 端口唤醒"]
    end

    subgraph TV["📺 客厅大屏设备 (Apple TV)"]
        TVOS_Browser["tvOS hsbtvbrowser 应用\n(WebKit / DOM点击 / JS注入)"]
        TVOS_System["tvOS 系统底座\n(Home / Menu / 音量 / 休眠唤醒)"]
    end

    subgraph AI_Engine["🧠 AI 算力矩阵"]
        MLX_Physical["端侧纯血 MLX 物理大模型\n(Qwen1.5 / SmolLM / Gemma-2)"]
        Custom_API["自定义大模型 API 模式\n(Ollama / DeepSeek / OpenAI)"]
        Builtin_Engine["内置离线端侧智能引擎\n(100% 秒级兜底保障)"]
    end

    UI --> Coordinator
    UI --> LLMManager
    Coordinator --> ScreenCh --> TVOS_Browser
    Coordinator --> NativeCh --> TVOS_System
    LLMManager --> MLX_Physical
    LLMManager --> Custom_API
    LLMManager -. 降级兜底 .-> Builtin_Engine
    LLMManager -- 生成控制脚本 --> ScreenCh
```

---

## 🧪 自动化测试与质量验收 (Testing & Verification)

项目内置针对端侧大模型全生命周期与双模通信的自动化集成测试套件 [`HSBLLMVerificationTest.m`](HSBWatchApp/HSBWatchCompanion/HSBLLMVerificationTest.m)，经由多代理团队与独立法医级审计代理 **Sentinel Victory Auditor** 验证，通过率 **100% (Pass: 11, Fail: 0)**：

- ✅ **Test 1**：三大官方大模型初始化与 ID 规范校验通过
- ✅ **Test 2**：三大官方大模型远端镜像源连通正常 (HTTP 200)
- ✅ **Test 3**：模型下载状态机流转 (None -> Downloading 42% -> Finished 100%) 与通知正常
- ✅ **Test 4**：捕获异常信号自动转为 Failed 状态并重置进度，彻底解除死锁与假死
- ✅ **Test 5**：本地缓存检测与安全删除接口运转正常 (沙盒权重安全清除与解绑)
- ✅ **Test 6.1**：模型 1 (Qwen1.5-0.5B) 激活并完成【同声传译】多语言业务调用
- ✅ **Test 6.2**：模型 2 (SmolLM-135M) 激活并生成【电视控制 JS 脚本】(`requestFullscreen`)
- ✅ **Test 6.3**：模型 3 (Gemma-2-2B-IT) 激活并完成【智能管家问答】结构化解答
- ✅ **Test 7**：自定义大模型 API 模式（Ollama/DeepSeek）状态与描述联动正常
- ✅ **Test 8**：物理模型空置或弱网异常时，100% 自动无缝降级至内置端侧智能引擎并正确生成 JS 脚本
- ✅ **Test 9**：环境防御与工程规范校验通过 (产物版本号严格为 1.0.0, 模拟器 Metal 算子安全隔离生效, 环境变量防御就绪)

---

## 🛠️ 编译与开发指南 (Build & Run Guide)

### 1. 开发环境要求
- **macOS**: 14.0+ (Sonoma 或更高版本，建议 Apple Silicon M 系列芯片)
- **Xcode**: 15.0+ / 16.0+ / 27.0+ (在 Xcode 27 中 Simulator 已整合为 DeviceHub)
- **SDK 要求**: iOS 17.0+ / watchOS 10.0+ / tvOS 17.0+
- **依赖管理**: Swift Package Manager (SPM，内置自动解析 `mlx-swift`, `swift-transformers` 等)

### 2. 源码获取与工程构建
```bash
# 1. 克隆代码仓库并进入工程目录
git clone https://github.com/never88gone/HSBRemoteBrowserTV.git
cd HSBRemoteBrowserTV

# 2. 使用 Xcode 打开主工程
open HSBWatchApp/HSBWatchApp.xcodeproj

# 3. 命令行静默编译检查 (iOS 配套端)
xcodebuild -project HSBWatchApp/HSBWatchApp.xcodeproj \
           -scheme HSBWatchCompanion \
           -configuration Debug \
           -destination 'generic/platform=iOS' \
           build

# 4. 命令行静默编译检查 (Apple Watch 端)
xcodebuild -project HSBWatchApp/HSBWatchApp.xcodeproj \
           -scheme 'HSBWatchApp Watch App' \
           -configuration Debug \
           -destination 'generic/platform=watchOS' \
           build
```

### 3. 在模拟器中快速运行自动化测试与场景直达
```bash
# 1. 启动 iPhone 模拟器并执行内置大模型全生命周期自检套件
xcrun simctl launch --terminate-running-process <SIMULATOR_UDID> com.never88gone.thlbrowserios -UITestRunLLMVerification YES
cat /tmp/llm_test_report.txt

# 2. 直达改版后的电视遥控中枢：浏览器控制与常用 JS 脚本芯片模式
xcrun simctl launch --terminate-running-process <SIMULATOR_UDID> com.never88gone.thlbrowserios -UITestOpenTVDetail YES -UITestInitialTab 1

# 3. 直达电视遥控中枢：视频控制与播放速率调节模式
xcrun simctl launch --terminate-running-process <SIMULATOR_UDID> com.never88gone.thlbrowserios -UITestOpenTVDetail YES -UITestInitialTab 0

# 4. 直达全屏触控板与 JS 控制界面
xcrun simctl launch --terminate-running-process <SIMULATOR_UDID> com.never88gone.thlbrowserios -UITestOpenBrowserControl YES

# 5. 直达统一设置中枢与端侧 AI 模型中心
xcrun simctl launch --terminate-running-process <SIMULATOR_UDID> com.never88gone.thlbrowserios -UITestOpenSettings YES
```

---

## 🛡️ App Store 审核规范与全场景离线保护 (App Store Compliance & Offline Resilience)

- **全场景常驻开放与离线体验保障**：应用常驻提供系统遥控、浏览器触控、IPTV 直播流与 PDF 演讲四大核心交互场景。在未连接局域网真实大屏或处于审核网络隔离环境中，手机端依然支持全功能触控微操离线体验、虚拟光标移动与多点手势模拟，彻底杜绝白屏或按钮失效风险，确保审核人员与用户能即时直观体验到核心功能；
- **完备的隐私权限说明**：
  - `NSLocalNetworkUsageDescription`：清楚阐述局域网 Bonjour 协议自动发现 Apple TV 的必要性；
  - `NSSpeechRecognitionUsageDescription`：合规声明语音搜索与大屏文字听写用途；
  - `NSMotionUsageDescription`：合规声明体感飞鼠与运动微操用途；
- **严格的版本号管理**：主工程、Info.plist 与配置文件的 `CFBundleShortVersionString` 严格锁定并核准为 **`1.0.0`**。

---

## 🤝 参与共建与技术反馈

糖葫芦遥控器秉持极致的用户体验与开源探索精神。
- 🐛 **Issue 报告**：欢迎提交 GitHub Issue 交流端侧 MLX 模型适配心得或功能构想；
- 📬 **应用内反馈**：通过「设置 -> 关于糖葫芦」直连开发团队。

*—— Designed with ❤️ for the ultimate big-screen experience.*
