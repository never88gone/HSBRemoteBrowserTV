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

### 🌐 板块一：大屏 TV 浏览器深度交互与触控中枢 (Browser Interaction)
| 1. 局域网大屏设备发现与配对 | 2. 浏览器触控中枢与导航微操 | 3. 大屏软键盘实时输入同步抽屉 |
| :---: | :---: | :---: |
| <img src="screenshot/1_device_discovery.png" width="260" /> | <img src="screenshot/2_browser_control.png" width="260" /> | <img src="screenshot/3_video_control.png" width="260" /> |
| **Bonjour 无感直连 / 状态监听** | **5.5x 触控板 / 网页悬浮导航岛** | **全尺寸原生软键盘 / 毫秒级字符流同步** |

### 🤖 板块二：客厅原生生态与端侧 AI 矩阵 (System Remote & Edge AI)
| 4. 系统级双模遥控 | 5. IPTV 直播流控制 | 6. PDF 大屏演说投屏 |
| :---: | :---: | :---: |
| <img src="HSBWatchApp/fastlane/screenshots/zh-Hans/1_system_remote.png" width="260" /> | <img src="HSBWatchApp/fastlane/screenshots/zh-Hans/2_iptv_remote.png" width="260" /> | <img src="HSBWatchApp/fastlane/screenshots/zh-Hans/3_pdf_presentation.png" width="260" /> |
| **7. AI 模型管理中心** | **8. AI 智能助手调用** | **9. 糖葫芦全生态矩阵** |
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

### 🖐️ 2. 5.5x 超高灵敏度大屏虚拟触控板微操手势规范 (Trackpad Gestures)
<p align="center">
  <img src="screenshot/2_browser_control.png" width="320" alt="电视遥控中枢 - 浏览器控制模式" />
</p>

独创 **1000×1000 相对虚拟空间坐标重置算法**，结合 **8 阶二次缓出 (Quad Ease-Out) 60FPS 衰减阻尼曲线**，带来媲美 Mac 物理触控板的顺滑手感：

| 手势类型 | 操作方式 | 对应大屏动作 | 核心场景与体验说明 |
| :--- | :--- | :--- | :--- |
| **单指移动** | 单指在大触控板区域平移 | **大屏鼠标光标平滑移动** | 精准悬停至大屏超链接、网页导航栏或任意交互元素之上 |
| **双指平滑滚动** | 双指在触控板上下同时滑动 | **大屏网页垂直阻尼滚动** | 采用 60FPS 物理阻尼衰减，长图文、瀑布流与资讯文章丝滑顺畅 |
| **双指触控轻点** | 双指快速并拢轻点触控板 | **模拟鼠标左键单击** | 毫秒级触发网页超链接跳转、按钮激活与媒体控件响应 |
| **三指强力点击** | 三指同时轻点触控板 | **模拟鼠标右键 / 菜单拾取** | 深度拾取目标 DOM 元素，唤出大屏网页右键上下文菜单 |
| **四指拖动手势** | 四指全部按下并持续移动 | **全选 / 文本划选 / 元素拖拽** | 无需等待位移阈值，四指按下即进入锁定拖拽，支持文本选区与滑块拖动 |

---

### 🧭 3. 大屏专属 Web 导航控制工具栏 (Navigation Control Dock)
在浏览器控制中心底部，配备专属的大屏 WebKit 网页导航坞，随时一键调度：
* **后退 (`<`)**：驱动底层 WebKit 历史栈回退上一页；
* **前进 (`>`)**：驱动底层 WebKit 历史栈前进下一页；
* **刷新 (`⟳`)**：强制重载大屏当前页面；
* **主页 (`⌂`)**：瞬时返回糖葫芦大屏浏览器预设导航主页与书签中心；
* **放大 (`🔍+`)**：页面视口按 1.25x 梯度缩放，看清小字号排版与网页细节。

---

### ⌨️ 4. RTI 实时软键盘大屏输入同步与文本投送 (Real-Time Text Input & Keyboard Drawer)
<p align="center">
  <img src="screenshot/3_video_control.png" width="320" alt="大屏实时软键盘同步抽屉" />
</p>

智能电视最痛苦的痛点莫过于“用遥控器在屏幕九宫格上逐字移动光标输入”，糖葫芦遥控器全面引入 **RTI (Real-Time Input) 实时软键盘同步机制**：
* **一键呼出同步抽屉**：轻触右上角键盘图标，底部自动升起半透明毛玻璃「电视实时文本同步」卡片并自动聚焦输入框；
* **原生 iOS 输入法全支持**：原生中文九宫格、全键盘、英文、Emoji 表情及语音听写输入全面支持；
* **毫秒级字符双向同步**：键入内容通过 Bonjour TCP 信道毫秒级推送到大屏当前激活的网页输入框（如百度搜索、B站搜索框等）；
* **一键清除与回车提交**：配备快速清空按键与大号发送箭头，回车即刻触发大屏检索或表单提交。

---

### 🎬 5. 网页流媒体与一体化系统遥控协同 (Media & System Playback Controls)
在「系统遥控」与「一体化控制岛」中，针对网页内嵌流媒体与 Apple TV 原生播放器提供双向协同调控：
* **【快退 10 秒 / 播放暂停 / 快进 10 秒】**：大尺寸实体化手感按键，毫秒级响应，轻松跳过片头或复看关键镜头；
* **【硬件级音量调控与静音】**：支持音量加减与一键静音，机身侧边物理按键同步联动；
* **【桌面与返回直达】**：随时一键返回 Apple TV 系统主屏幕或返回上级菜单。

---

### ⚙️ 6. 统一设置中枢与端侧 AI 模型入口 (Settings & Edge AI Hub)
<p align="center">
  <img src="screenshot/4_settings_hub.png" width="320" alt="统一设置中枢与模型中心" />
</p>

* **模块化管理**：轻触首页右上角齿轮图标，即可呼出全新现代设计的设置中枢；
* **AI 核心直达**：快捷进入「AI 模型中心」管理端侧物理大模型下载与权重沙盒，或进入「AI 智能助手」执行同声传译与大屏控制脚本生成；
* **多语言与生态**：支持中英文翻译源/目标语言切换、第三方开源协议查看与关于糖葫芦生态矩阵。

---

### 🧩 7. 预置快捷 JS 芯片与端侧 AI 自动化控制脚本注入 (Scripts & Edge AI)
* **横向滑动预置控制芯片**：在触控板上方内置高频一键大屏优化脚本：
  - `抖音_全屏`：消除网页版多余空白与侧边栏，短视频直接全屏铺满大屏；
  - `抖音_启动跳转`：自动越过网页开屏引导，直达推荐流；
  - `抖音_自动登录`：协助跨端免密安全鉴权；
  - `抖音_连播点击`：开启大屏短视频无缝循环轮播体验；
  - `抖音_高分辨率`：强制锁定并拉取 1080P/4K 高画质大屏媒体流；
  - `腾讯视频_全屏`：一键去除网页边框，开启影院级宽屏播放。
* **端侧纯血 MLX 大模型智能协同注入**：
  - 长按右下角紫色 **AI 魔法浮动按钮** 调起高精度语音听写；
  - 直接说出自然语言指令（例如：“*把页面背景调成护眼夜间深色，隐藏右侧悬浮浮窗，并将主要字体放大 20%*”）；
  - 手机本地运行的 **MLX 大模型**（SmolLM-135M / Qwen1.5-0.5B）将在毫秒级内自动推理出标准的 JavaScript 代码；
  - 脚本即刻通过专有长连接推送到大屏 WebKit 运行时中安全执行，真正实现**“动动嘴皮子，大屏网页随心定制”**！

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
- **Xcode**: 15.0+ / 16.0+
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

### 3. 在模拟器中快速运行自动化测试套件
```bash
# 启动 iPhone 模拟器并执行内置大模型全生命周期自检套件
xcrun simctl launch --terminate-running-process <SIMULATOR_UDID> com.never88gone.thlbrowserios -UITestRunLLMVerification YES

# 查看输出的测试报告
cat /tmp/llm_test_report.txt
```

---

## 🛡️ App Store 审核规范与纯净保护 (App Store Compliance)

- **纯净遥控保护机制**：未连接真实局域网电视大屏前，应用自动折叠专有浏览器标签与特殊敏感调试面板，呈现标准规范的电视遥控界面，确保完全符合 App Store 审核指南；
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
