# 🍬 糖葫芦遥控器 (Tanghulu Smart Remote)

![Platform](https://img.shields.io/badge/Platform-iOS%2017.0+%20%7C%20tvOS%2017.0+-007AFF.svg?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343.svg?style=for-the-badge&logo=swift)
![AI](https://img.shields.io/badge/Edge%20AI-MLX%20LLM%20%7C%20CoreML-8A2BE2.svg?style=for-the-badge&logo=openai)
![Version](https://img.shields.io/badge/Version-1.0.0-34C759.svg?style=for-the-badge)

> **专为 Apple TV 与客厅大屏打造的双模无线遥控器与端侧 AI 交互中枢。**  
> 融合 Apple TV 原生系统级控制、5.5x 阻尼微操触控板、RTI 实时键盘同步与 Apple Silicon MLX 端侧大模型矩阵，带来毫秒级响应的极简操控体验。

---

## 📸 界面精选 (Screenshots)

| 1. 原生极光遥控 | 2. 微操触控板 | 3. 大屏应用生态 | 4. 端侧 AI 助手 |
| :---: | :---: | :---: | :---: |
| <img src="screenshot/unified_remote_tab.png" width="200" /> | <img src="screenshot/unified_touchpad.png" width="200" /> | <img src="screenshot/unified_apps_grid.png" width="200" /> | <img src="screenshot/6_ai_assistant.png" width="200" /> |
| **原生系统轮盘<br>真机实测毫秒级直连** | **阻尼滑动 / 悬浮光标<br>大屏网页高精微操** | **一键直达客厅应用<br>浏览器 / 直播 / 演说** | **同声传译 / TV 控制<br>100% 离线隐私安全** |

---

## ✨ 核心特性 (Features)

- **🍎 Apple TV 原生双模协议**：
  - 支持 Apple TV Companion 原生协议，基于 SRP-6a 与 ChaCha20-Poly1305 加密信道直连；
  - 局域网 Bonjour 毫秒级免密自愈重连，完美支持 D-Pad、Home、Menu、播放与音量等全局物理控制；
  - 具备智能硬件过滤能力，自动识别并精准锁定局域网内的 Apple TV 硬件设备。
- **🎯 5.5x 微操触控与键盘同步**：
  - 提供阻尼手感触控板与平滑光标，解决电视网页浏览操作痛点；
  - 内置 RTI (Remote Text Input) 实时软键盘同步，打字秒上大屏。
- **🧠 端侧纯血 MLX 大模型**：
  - 适配 Apple Silicon MLX 离线推理矩阵（Qwen1.5-0.5B / SmolLM-135M / Gemma-2-2B-IT）；
  - 支持多语言同声传译、大屏控制脚本生成与客厅管家问答，无模型时秒级降级至内置智能引擎。

---

## ⚡ 快速开始 (Quick Start)

### 编译构建
```bash
# 1. 克隆代码仓库
git clone https://github.com/never88gone/HSBRemoteBrowserTV.git
cd HSBRemoteBrowserTV

# 2. 编译测试 iOS 伴侣端工程
xcodebuild -project HSBWatchApp/HSBWatchApp.xcodeproj \
           -scheme HSBWatchCompanion \
           -configuration Debug \
           -destination 'generic/platform=iOS' \
           build
```

---

## 📄 许可 (License)

Copyright © 2026 Tanghulu Team. All rights reserved.
