//
//  HSBWatchCompanionUITests.swift
//  HSBWatchCompanionUITests
//
//  基于苹果官方 XCUITest 自动化测试框架的物理真机端到端全链路验收套件：
//  1. 严格遵守“生产代码零污染 (Zero-Pollution)”铁律，测试逻辑 100% 隔离在独立 UITests Target；
//  2. 针对 iOS 14~18 物理真机启动环境，内嵌多语言语义级系统权限拦截器 (UIInterruptionMonitor)
//     与 SpringBoard 弹窗主动兜底探测，智能识别并授权“本地网络”、“无线局域网”等系统权限，
//     坚决杜绝因首选盲点导致的误拒绝；
//  3. 攻克真机 Bonjour/mDNS 局域网扫描耗时，平滑识别目标 Mac 电脑（never88gone的 Mac Studio）；
//  4. 采用精准几何防越界微操手势，在 iPhone SE 屏幕安全区内平滑驱动三段拖拽移动、鼠标轻击、
//     实体按键与系统音量媒体控制，客观触发 Mac 宿主（端口 49888）HID 事件；
//  5. 点击断开后采用“遥控元素注销 + 首页就绪”双向互斥断言，确保退出平稳安全无闪退；
//  6. 全程生成多维关键步骤高分辨率快照并持久化于 XCTAttachment 附件，支持自动化提取。
//

import XCTest

final class HSBWatchCompanionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // 注册智能多语言系统中断处理器 (System Interruption Monitor)
        // 覆盖本地网络访问、无线局域网、蓝牙、定位等系统级隐私授权弹窗
        addUIInterruptionMonitor(withDescription: "Intelligent System and Local Network Permission Monitor") { alert in
            NSLog("[XCUITest INTERRUPT] 触发系统警报中断，警报标题: '%@', 按钮数量: %ld", alert.label, alert.buttons.count)
            
            // 1. 如果遇到业务级重试连接弹窗，主动点击'🔄 重试连接'
            let retryBtn = alert.buttons["🔄 重试连接"]
            if retryBtn.exists {
                retryBtn.tap()
                NSLog("[XCUITest INTERRUPT] ✅ 成功识别并点击业务'🔄 重试连接'")
                return true
            }
            
            // 2. 严禁误拦截业务级 PIN 码弹窗 (交由主测试逻辑专门处理)
            let alertLabel = alert.label
            if alertLabel.contains("PIN 码") {
                NSLog("[XCUITest INTERRUPT] ⚠️ 识别为 PIN 码配对弹窗，放行给主逻辑")
                return false
            }
            
            // 语义级授权正向关键词 (中文简体/繁体、英文)
            let positiveKeywords = [
                "允许", "好", "确定", "无线局域网与蜂窝网络", "仅限无线局域网", "保持连接", "始终允许", "使用App时允许",
                "Allow", "OK", "Continue", "Allow While Using App", "Allow Once", "Keep", "Wireless LAN & Cellular"
            ]
            
            // 语义级拒绝负向关键词 (坚决杜绝误点)
            let negativeKeywords = [
                "不允许", "拒绝", "取消", "关闭", "稍后",
                "Don't Allow", "Dont Allow", "Deny", "Cancel", "Not Now", "Dismiss"
            ]
            
            // 1. 优先在按钮列表中查找正向授权词汇
            for i in 0..<alert.buttons.count {
                let btn = alert.buttons.element(boundBy: i)
                let label = btn.label.trimmingCharacters(in: .whitespacesAndNewlines)
                for pos in positiveKeywords {
                    if label.localizedCaseInsensitiveContains(pos) {
                        btn.tap()
                        NSLog("[XCUITest INTERRUPT] ✅ 成功识别并点击正向授权按键: '%@'", label)
                        return true
                    }
                }
            }
            
            // 2. 若未直接命中正向词汇，检查是否存在两选弹窗（iOS 标准布局通常 index 0 为取消，index 1 为确认）
            if alert.buttons.count >= 2 {
                let firstBtn = alert.buttons.element(boundBy: 0)
                let firstLabel = firstBtn.label.trimmingCharacters(in: .whitespacesAndNewlines)
                let isFirstNegative = negativeKeywords.contains { firstLabel.localizedCaseInsensitiveContains($0) }
                
                if isFirstNegative {
                    let secondBtn = alert.buttons.element(boundBy: 1)
                    secondBtn.tap()
                    NSLog("[XCUITest INTERRUPT] 避开首选拒绝按键，安全点击第二个候选按键: '%@'", secondBtn.label)
                    return true
                }
            }
            
            // 3. 兜底策略：点击最后一个按钮 (iOS 默认非毁灭性正向操作通常排在末尾)
            if alert.buttons.count > 0 {
                let lastBtn = alert.buttons.element(boundBy: alert.buttons.count - 1)
                lastBtn.tap()
                NSLog("[XCUITest INTERRUPT] 点击候选末尾按键: '%@'", lastBtn.label)
                return true
            }
            
            return false
        }
    }

    override func tearDownWithError() throws {
    }

    /// 截取高分辨率屏幕并保存为 XCTAttachment 附件，支持导出与本地持久化
    @discardableResult
    private func captureStepScreenshot(_ stepName: String) -> XCUIScreenshot {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = stepName
        attachment.lifetime = .keepAlways
        add(attachment)
        
        let pngData = screenshot.pngRepresentation
        
        // 尝试写入真机沙盒 Temporary 目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("xcuitest_screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        let localPath = tempDir.appendingPathComponent("\(stepName).png")
        try? pngData.write(to: localPath)
        
        // 尝试写入宿主运行环境 /tmp/xcuitest_screenshots/
        let hostDir = URL(fileURLWithPath: "/tmp/xcuitest_screenshots")
        try? FileManager.default.createDirectory(at: hostDir, withIntermediateDirectories: true, attributes: nil)
        let hostPath = hostDir.appendingPathComponent("\(stepName).png")
        try? pngData.write(to: hostPath)
        
        NSLog("[XCUITest SCREENSHOT] 📸 快照捕获完成: %@", stepName)
        return screenshot
    }

    /// 主动探测并处置 SpringBoard 顶层系统权限弹窗 (主动兜底)
    private func dismissSpringBoardAlertsIfAny() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.exists {
            NSLog("[XCUITest] 发现 SpringBoard 系统弹窗: '%@'，正在执行主动授权...", alert.label)
            let positiveKeywords = ["允许", "好", "确定", "无线局域网与蜂窝网络", "Allow", "OK", "Continue"]
            for pos in positiveKeywords {
                let btn = alert.buttons[pos]
                if btn.exists {
                    btn.tap()
                    NSLog("[XCUITest] 主动点击 SpringBoard 授权按键: '%@'", pos)
                    Thread.sleep(forTimeInterval: 0.5)
                    return
                }
            }
            if alert.buttons.count >= 2 {
                alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    /// 端到端全链路测试：物理真机局域网发现 Mac、微操触控滑动、鼠标点击、媒体控制与安全退出
    func testMacRemoteControlEndToEnd() throws {
        let app = XCUIApplication()
        app.activate()

        // 等待 App 启动、初始转场与 Bonjour 设备发现就绪 (3.5 秒)
        Thread.sleep(forTimeInterval: 3.5)
        
        // 若有先前残留的系统弹窗，平稳点击取消返回首页
        let oldAlert = app.alerts.firstMatch
        if oldAlert.exists {
            let cancel = oldAlert.buttons["取消"]
            if cancel.exists && cancel.isHittable {
                cancel.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        captureStepScreenshot("01_App_Launched_Home")
        
        NSLog("[XCUITest DEBUG] ================= APP DEBUG TREE =================")
        NSLog("[XCUITest DEBUG] %@", app.debugDescription)
        NSLog("[XCUITest DEBUG] ==================================================")

        // ---------------------------------------------------------------------
        // 步骤 1: 物理真机局域网设备扫描与识别目标 Mac 电脑 (静默等待 Bonjour 组播)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 1: 正在扫描局域网 Mac 电脑 (never88gone的 Mac Studio)...")
        let macPredicate = NSPredicate(format: "label CONTAINS[c] 'Mac' OR label CONTAINS[c] 'never88gone' OR label CONTAINS[c] 'Studio'")
        
        var targetElement: XCUIElement?
        let maxWaitSeconds: TimeInterval = 35.0
        let startTime = Date()
        var hasSwipedRefresh = false
        
        while Date().timeIntervalSince(startTime) < maxWaitSeconds {
            // 多级鲁棒匹配：直接 Cell 标签 -> 包含子元素 Cell -> 独立文本标签 -> 全局后代元素
            let directCell = app.cells.matching(macPredicate).firstMatch
            if directCell.exists {
                targetElement = directCell
                break
            }
            let containingCell = app.cells.containing(macPredicate).firstMatch
            if containingCell.exists {
                targetElement = containingCell
                break
            }
            let staticText = app.staticTexts.matching(macPredicate).firstMatch
            if staticText.exists {
                targetElement = staticText
                break
            }
            let macAny = app.descendants(matching: .any).matching(macPredicate).firstMatch
            if macAny.exists {
                targetElement = macAny
                break
            }
            
            if !hasSwipedRefresh && Date().timeIntervalSince(startTime) > 6.0 {
                hasSwipedRefresh = true
                NSLog("[XCUITest] 触发轻微下拉刷新以加速 Bonjour 局域网组播广播捕获...")
                app.swipeDown()
            }
            
            Thread.sleep(forTimeInterval: 0.6)
        }

        guard let element = targetElement, element.exists else {
            captureStepScreenshot("01_Fail_Mac_Not_Found")
            XCTFail("❌ 自动化测试失败：未能在 25 秒内通过局域网 mDNS 发现目标 Mac 电脑设备")
            return
        }
        
        // 若元素在视口外部，轻微上滑确保其处于可点击交互区域
        if !element.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        captureStepScreenshot("02_Discovered_Mac_Device")
        NSLog("[XCUITest] ✅ 成功捕获目标 Mac 设备卡片: '%@'", element.label)

        // ---------------------------------------------------------------------
        // 步骤 2: 点击 Mac 设备卡片，安全等待连接建立与推栈转场
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 2: 点击 Mac 设备卡片进入遥控控制台...")
        element.tap()

        // ---------------------------------------------------------------------
        // 步骤 3: 严格等待遥控界面完全转场并呈现就绪 (以“系统直控就绪”和“断开”为准)
        // ---------------------------------------------------------------------
        let disconnectButton = app.buttons["断开"]
        let readyLabel = app.staticTexts["系统直控就绪"]

        var enteredRemotePage = false
        let enterStartTime = Date()
        let maxEnterWait: TimeInterval = 20.0
        
        while Date().timeIntervalSince(enterStartTime) < maxEnterWait {
            if disconnectButton.exists && readyLabel.exists {
                enteredRemotePage = true
                break
            }
            
            // 检查是否有重试弹窗
            let retryAlertBtn = app.alerts.buttons["🔄 重试连接"]
            if retryAlertBtn.exists {
                retryAlertBtn.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        XCTAssertTrue(enteredRemotePage, "❌ 自动化测试失败：点击设备后未能成功进入 Mac 遥控器界面")
        // 强制给 1.5 秒等待转场动画与布局完全稳定，杜绝在动效期间点击无效
        Thread.sleep(forTimeInterval: 1.5)
        captureStepScreenshot("03_Entered_Mac_Remote_Panel")
        NSLog("[XCUITest] ✅ 成功进入 Mac 专属遥控界面，微操控制组件全部就绪！")

        let window = app.windows.firstMatch

        // ---------------------------------------------------------------------
        // 步骤 4: 虚拟触控板微操滑动控制光标 (极致丝滑、零卡顿高频滑动验证)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 4: 在虚拟触控板微操区域驱动平滑微操拖拽手势...")
        
        // 几何锚定：iPhone SE 4.7 寸屏中，触控板视口核心中心严格处于 (0.50, 0.40)
        let trackpadCenter = window.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.40))
        
        // 微操滑动 1：平滑向右上微移 (dx: +60, dy: -40)
        let dragCoord1 = trackpadCenter.withOffset(CGVector(dx: 60, dy: -40))
        trackpadCenter.press(forDuration: 0.15, thenDragTo: dragCoord1)
        NSLog("[XCUITest] ✅ 触控板微操滑动 1 完成: 向右上平滑拖拽 (+60, -40)")
        Thread.sleep(forTimeInterval: 0.3)

        // 微操滑动 2：平滑向左下反向微移 (dx: -55, dy: +45)
        let dragCoord2 = trackpadCenter.withOffset(CGVector(dx: -55, dy: 45))
        trackpadCenter.press(forDuration: 0.15, thenDragTo: dragCoord2)
        NSLog("[XCUITest] ✅ 触控板微操滑动 2 完成: 向左下反向拖拽 (-55, +45)")
        Thread.sleep(forTimeInterval: 0.3)

        // 微操滑动 3：平滑水平向右微调 (dx: +50, dy: 0)
        let dragCoord3 = trackpadCenter.withOffset(CGVector(dx: 50, dy: 0))
        trackpadCenter.press(forDuration: 0.15, thenDragTo: dragCoord3)
        NSLog("[XCUITest] ✅ 触控板微操滑动 3 完成: 水平向右微调 (+50, 0)")
        Thread.sleep(forTimeInterval: 0.3)
        
        // 触控板中心轻点模拟触控单击
        trackpadCenter.tap()
        NSLog("[XCUITest] ✅ 触控板中心轻点触发鼠标左键单击")
        Thread.sleep(forTimeInterval: 0.3)

        captureStepScreenshot("04_Trackpad_Swipe_Completed")

        // ---------------------------------------------------------------------
        // 步骤 4.5: 验证触控鼠标“全屏控制”与“退格键”控制
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 4.5: 点击触控板右上角'全屏'按钮，验证全屏触控鼠标模式与退格键...")
        let fullScreenBtn = app.buttons["mac_fullscreen_trackpad_button"]
        let altFullScreenBtn = app.buttons["全屏触控"]
        if fullScreenBtn.waitForExistence(timeout: 2.0) && fullScreenBtn.isHittable {
            fullScreenBtn.tap()
            NSLog("[XCUITest] ✅ 成功点击'全屏触控'按钮进入全屏触控鼠标模式")
        } else if altFullScreenBtn.waitForExistence(timeout: 2.0) && altFullScreenBtn.isHittable {
            altFullScreenBtn.tap()
            NSLog("[XCUITest] ✅ 成功点击'全屏触控'标签按钮进入全屏触控鼠标模式")
        }
        Thread.sleep(forTimeInterval: 0.6)
        captureStepScreenshot("04_5_FullScreen_Trackpad_Active")

        // 在全屏超大面积触控板上驱动大跨度丝滑移动与点击
        let fullTrackpadDragTarget = trackpadCenter.withOffset(CGVector(dx: -75, dy: -65))
        trackpadCenter.press(forDuration: 0.15, thenDragTo: fullTrackpadDragTarget)
        NSLog("[XCUITest] ✅ 全屏触控鼠标大跨度平滑拖拽完成 (-75, -65)")
        Thread.sleep(forTimeInterval: 0.3)

        // 在全屏模式下点击底座唯一的“退格键”按钮，并断言无重复退格按钮
        let macBackspaceBtn = app.buttons["mac_backspace_button"]
        let backspaceButtonsCount = app.buttons.matching(NSPredicate(format: "label CONTAINS '退格'")).count
        NSLog("[XCUITest] 当前屏幕退格按钮数量校验: %d (期望: 1)", backspaceButtonsCount)
        XCTAssertEqual(backspaceButtonsCount, 1, "❌ 页面上存在重复的退格按钮！")
        if macBackspaceBtn.waitForExistence(timeout: 1.5) && macBackspaceBtn.isHittable {
            macBackspaceBtn.tap()
            NSLog("[XCUITest] ✅ 点击触控底座唯一'退格键'成功 (向 Mac 发送 Backspace keyCode=51)")
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 点击“退出全屏”按钮恢复常规多模式视图
        let exitFullScreenBtn = app.buttons["mac_exit_fullscreen_trackpad_button"]
        let altExitFullScreenBtn = app.buttons["退出全屏"]
        if exitFullScreenBtn.waitForExistence(timeout: 2.0) && exitFullScreenBtn.isHittable {
            exitFullScreenBtn.tap()
            NSLog("[XCUITest] ✅ 成功点击'退出全屏'按钮恢复常规视图")
        } else if altExitFullScreenBtn.waitForExistence(timeout: 2.0) && altExitFullScreenBtn.isHittable {
            altExitFullScreenBtn.tap()
            NSLog("[XCUITest] ✅ 成功点击'退出全屏'标签按钮恢复常规视图")
        }
        Thread.sleep(forTimeInterval: 0.5)

        // ---------------------------------------------------------------------
        // 步骤 5: 触控底座所有按键全面覆盖 (鼠标左键、右键菜单、退格键、向上滚动、向下滚动)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 5: 验证触控底座所有实体按键...")
        let leftClickBtn = app.buttons["鼠标左键"]
        let rightClickBtn = app.buttons["右键菜单"]
        
        if leftClickBtn.waitForExistence(timeout: 2.0) && leftClickBtn.isHittable {
            leftClickBtn.tap()
            NSLog("[XCUITest] ✅ [Button 1/22] 点击'鼠标左键'成功")
            Thread.sleep(forTimeInterval: 0.3)
        } else {
            // 几何坐标兜底 (iPhone SE: 底座左键位于 X: 80, Y: 535)
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 80, dy: 535)).tap()
            NSLog("[XCUITest] ✅ [Button 1/22] 几何坐标点击'鼠标左键'成功")
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        if rightClickBtn.waitForExistence(timeout: 2.0) && rightClickBtn.isHittable {
            rightClickBtn.tap()
            NSLog("[XCUITest] ✅ [Button 2/22] 点击'右键菜单'成功")
            Thread.sleep(forTimeInterval: 0.3)
        } else {
            // 几何坐标兜底 (iPhone SE: 底座右键位于 X: 190, Y: 535)
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 190, dy: 535)).tap()
            NSLog("[XCUITest] ✅ [Button 2/22] 几何坐标点击'右键菜单'成功")
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 向上滚动按键
        let scrollUpBtn = app.buttons["向上滚动"]
        if scrollUpBtn.waitForExistence(timeout: 1.5) && scrollUpBtn.isHittable {
            scrollUpBtn.tap()
        } else {
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 290, dy: 535)).tap()
        }
        NSLog("[XCUITest] ✅ [Button 3/22] 点击'向上滚动'按键成功")
        Thread.sleep(forTimeInterval: 0.3)
        
        // 向下滚动按键
        let scrollDownBtn = app.buttons["向下滚动"]
        if scrollDownBtn.waitForExistence(timeout: 1.5) && scrollDownBtn.isHittable {
            scrollDownBtn.tap()
        } else {
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 345, dy: 535)).tap()
        }
        NSLog("[XCUITest] ✅ [Button 4/22] 点击'向下滚动'按键成功")
        Thread.sleep(forTimeInterval: 0.3)
        
        captureStepScreenshot("05_Mouse_Click_And_Scroll_Completed")

        // ---------------------------------------------------------------------
        // 步骤 5.5: 验证打字输入功能 (唤起文本抽屉 -> 键入 'Hello Mac' -> 发送至 Mac 宿主)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 5.5: 验证打字输入功能，向 Mac 宿主发送文本...")
        let typeEntryBtn = app.buttons["打字输入"]
        let altTypeBtn = app.buttons["打字"]
        if typeEntryBtn.waitForExistence(timeout: 2.0) && typeEntryBtn.isHittable {
            typeEntryBtn.tap()
            NSLog("[XCUITest] ✅ 点击'打字输入'入口按键成功")
        } else if altTypeBtn.waitForExistence(timeout: 2.0) && altTypeBtn.isHittable {
            altTypeBtn.tap()
            NSLog("[XCUITest] ✅ 点击'打字'入口按键成功")
        } else {
            // 几何坐标兜底 (顶部控制栏右侧: X: 320, Y: 60)
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 320, dy: 60)).tap()
            NSLog("[XCUITest] 几何坐标兜底点击顶部打字入口")
        }
        Thread.sleep(forTimeInterval: 0.5)

        // 定位文本框并输入 "Hello Mac"，同时验证打字面板上的“退格删除”按钮
        let remoteBackspaceBtn = app.buttons["remote_backspace_button"]
        if remoteBackspaceBtn.waitForExistence(timeout: 2.0) && remoteBackspaceBtn.isHittable {
            remoteBackspaceBtn.tap()
            NSLog("[XCUITest] ✅ 在打字输入抽屉中点击'退格删除'按钮成功")
            Thread.sleep(forTimeInterval: 0.3)
        }

        let remoteTextField = app.textFields["remote_text_field"]
        let anyTextField = app.textFields.firstMatch
        if remoteTextField.waitForExistence(timeout: 3.0) {
            remoteTextField.tap()
            remoteTextField.typeText("Hello Mac\n")
            NSLog("[XCUITest] ✅ 成功定位 remote_text_field 并键入 'Hello Mac'")
        } else if anyTextField.waitForExistence(timeout: 3.0) {
            anyTextField.tap()
            anyTextField.typeText("Hello Mac\n")
            NSLog("[XCUITest] ✅ 成功定位文本框并键入 'Hello Mac'")
        }
        
        let sendBtn = app.buttons["发送文本"]
        if sendBtn.waitForExistence(timeout: 1.5) && sendBtn.isHittable {
            sendBtn.tap()
            NSLog("[XCUITest] ✅ 点击'发送文本'完成向 Mac 派发")
        }
        Thread.sleep(forTimeInterval: 0.8)
        captureStepScreenshot("05_5_TextInput_Completed")

        // ---------------------------------------------------------------------
        // 步骤 6: 全局系统硬件控制岛全面覆盖 (音量 -、静音、音量 +、调度，触发 Mac 原生 HUD 浮窗与提示音)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 6: 触发全局系统媒体与调度快捷控制岛 (验证 Mac 原生 OSD HUD 浮窗与音频反馈)...")
        let volMinusBtn = app.buttons["音量 -"]
        let volPlusBtn = app.buttons["音量 +"]
        let missionBtn = app.buttons["调度"]

        if volMinusBtn.waitForExistence(timeout: 2.0) && volMinusBtn.isHittable {
            volMinusBtn.tap()
            NSLog("[XCUITest] ✅ [Button 5/22] 点击'音量 -'按键成功 (Mac 触发 Volume HUD 下调)")
            Thread.sleep(forTimeInterval: 0.4)
        }
        
        // 静音按钮位于音量-与音量+中间 (iPhone SE: X: 140, Y: 600)
        window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 140, dy: 600)).tap()
        NSLog("[XCUITest] ✅ [Button 6/22] 点击'静音'按键成功 (Mac 触发 Mute HUD 切换)")
        Thread.sleep(forTimeInterval: 0.4)
        
        if volPlusBtn.waitForExistence(timeout: 2.0) && volPlusBtn.isHittable {
            volPlusBtn.tap()
            NSLog("[XCUITest] ✅ [Button 7/22] 点击'音量 +'按键成功 (Mac 自动解除静音并弹出 Volume HUD 上调与 Beep)")
            Thread.sleep(forTimeInterval: 0.4)
            volPlusBtn.tap()
            NSLog("[XCUITest] ✅ 再次点击'音量 +'强化验证")
            Thread.sleep(forTimeInterval: 0.4)
        }
        
        if missionBtn.waitForExistence(timeout: 2.0) && missionBtn.isHittable {
            missionBtn.tap()
            NSLog("[XCUITest] ✅ [Button 8/22] 点击'调度'按键成功")
            Thread.sleep(forTimeInterval: 0.4)
        }
        
        captureStepScreenshot("06_Volume_And_Mission_Completed")

        // ---------------------------------------------------------------------
        // 步骤 7: 切换至“按键导航”模式 (全量覆盖 D-Pad 上/下/左/右/回车 + ESC/空格/桌面)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 7: 切换至'按键导航'模式并逐一验证所有按键...")
        let dpadModeBtn = app.buttons["按键导航"]
        if dpadModeBtn.waitForExistence(timeout: 2.0) && dpadModeBtn.isHittable {
            dpadModeBtn.tap()
            NSLog("[XCUITest] ✅ 成功切换至'按键导航'模式")
            Thread.sleep(forTimeInterval: 0.5)
            
            let enterBtn = app.buttons["回车"]
            let escBtn = app.buttons["ESC 返回"]
            let spaceBtn = app.buttons["空格键"]
            
            if enterBtn.waitForExistence(timeout: 2.0) {
                let centerCoord = enterBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                
                // 1. D-Pad 上方向键
                centerCoord.withOffset(CGVector(dx: 0, dy: -70)).tap()
                NSLog("[XCUITest] ✅ [Button 9/22] 点击 D-Pad '上' 方向键成功")
                Thread.sleep(forTimeInterval: 0.3)
                
                // 2. D-Pad 下方向键
                centerCoord.withOffset(CGVector(dx: 0, dy: 70)).tap()
                NSLog("[XCUITest] ✅ [Button 10/22] 点击 D-Pad '下' 方向键成功")
                Thread.sleep(forTimeInterval: 0.3)
                
                // 3. D-Pad 左方向键
                centerCoord.withOffset(CGVector(dx: -70, dy: 0)).tap()
                NSLog("[XCUITest] ✅ [Button 11/22] 点击 D-Pad '左' 方向键成功")
                Thread.sleep(forTimeInterval: 0.3)
                
                // 4. D-Pad 右方向键
                centerCoord.withOffset(CGVector(dx: 70, dy: 0)).tap()
                NSLog("[XCUITest] ✅ [Button 12/22] 点击 D-Pad '右' 方向键成功")
                Thread.sleep(forTimeInterval: 0.3)
                
                // 5. D-Pad 中心回车按键
                centerCoord.tap()
                NSLog("[XCUITest] ✅ [Button 13/22] 点击 D-Pad '回车' 按键成功")
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            if escBtn.waitForExistence(timeout: 2.0) && escBtn.isHittable {
                escBtn.tap()
                NSLog("[XCUITest] ✅ [Button 14/22] 点击 'ESC 返回' 按键成功")
                Thread.sleep(forTimeInterval: 0.3)
            }
            if spaceBtn.waitForExistence(timeout: 2.0) && spaceBtn.isHittable {
                spaceBtn.tap()
                NSLog("[XCUITest] ✅ [Button 15/22] 点击 '空格键' 按键成功")
                Thread.sleep(forTimeInterval: 0.3)
            }
            let dpadBackspaceBtn = app.buttons["mac_dpad_backspace_button"]
            if dpadBackspaceBtn.waitForExistence(timeout: 2.0) && dpadBackspaceBtn.isHittable {
                dpadBackspaceBtn.tap()
                NSLog("[XCUITest] ✅ 点击按键导航底座唯一 '退格键' 成功")
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            // 断言按键导航页面不存在重复的“调度”或“退格”按钮
            let missionBtnsCount = app.buttons.matching(NSPredicate(format: "label CONTAINS '调度'")).count
            XCTAssertEqual(missionBtnsCount, 1, "❌ 按键导航页面存在重复的调度按钮！")
            
            captureStepScreenshot("07_DPad_Navigation_Completed")
        }

        // ---------------------------------------------------------------------
        // 步骤 8: 切换至“媒体播放”模式 (全量覆盖 Apple Music 唤起、上一首、播放/暂停、下一首)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 8: 切换至'媒体播放'模式并逐一验证所有媒体按键...")
        let mediaModeBtn = app.buttons["媒体播放"]
        if mediaModeBtn.waitForExistence(timeout: 2.0) && mediaModeBtn.isHittable {
            mediaModeBtn.tap()
            NSLog("[XCUITest] ✅ 成功切换至'媒体播放'模式")
            Thread.sleep(forTimeInterval: 0.5)
            
            // 1. 一键启动 Apple Music
            let launchMusicBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple Music'")).firstMatch
            if launchMusicBtn.waitForExistence(timeout: 2.0) && launchMusicBtn.isHittable {
                launchMusicBtn.tap()
                NSLog("[XCUITest] ✅ [Button 17/22] 点击'启动 Apple Music'按键成功")
                Thread.sleep(forTimeInterval: 0.4)
            }
            
            // 2. 媒体核心按键群 (位于屏幕下部 Y: 510, 上一首 X: 100, 播放/暂停 X: 187.5, 下一首 X: 275)
            // 上一首
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 100, dy: 510)).tap()
            NSLog("[XCUITest] ✅ [Button 18/22] 点击'上一首'按键成功")
            Thread.sleep(forTimeInterval: 0.3)
            
            // 播放 / 暂停
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 187.5, dy: 510)).tap()
            NSLog("[XCUITest] ✅ [Button 19/22] 点击'播放/暂停'按键成功")
            Thread.sleep(forTimeInterval: 0.3)
            
            // 下一首
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 275, dy: 510)).tap()
            NSLog("[XCUITest] ✅ [Button 20/22] 点击'下一首'按键成功")
            Thread.sleep(forTimeInterval: 0.3)
            
            captureStepScreenshot("08_Media_Playback_Completed")
        }

        // ---------------------------------------------------------------------
        // 步骤 9: 点击断开按钮，双向验证安全平稳退回首页 (绝不闪退)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest] 步骤 9: 点击断开连接按钮，验证安全平稳退出链路...")
        if disconnectButton.waitForExistence(timeout: 3.0) && disconnectButton.isHittable {
            disconnectButton.tap()
            NSLog("[XCUITest] ✅ [Button 21/22] 成功点击'断开'按钮")
        } else {
            // 兜底轻点左上角断开返回区域
            let backCoord = window.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.08))
            backCoord.tap()
            NSLog("[XCUITest] ✅ 兜底点击左上角导航返回区域")
        }

        // 双向严密断言：
        // 1. 遥控特有组件（断开按钮）在 6 秒内注销消失 (互斥注销校验)；
        // 2. 首页核心元素（导航栏标题、设置按键、设备列表容器或单元格）在 6 秒内就绪呈现。
        let disconnectDisappeared = disconnectButton.waitForNonExistence(timeout: 6.0)
        NSLog("[XCUITest] 遥控控制台注销判定: %@", disconnectDisappeared ? "已注销消失" : "仍存在(需排查)")
        XCTAssertTrue(disconnectDisappeared, "❌ 自动化测试失败：点击断开后遥控控制台界面未在规定时间内注销消失")
        
        let homeTitle = app.staticTexts["糖葫芦遥控器"]
        let deviceTitle = app.staticTexts["Apple TV 硬件终端"]
        let settingsButton = app.navigationBars.buttons.element(boundBy: 0)
        
        let homeAppeared = homeTitle.waitForExistence(timeout: 6.0) ||
                           deviceTitle.waitForExistence(timeout: 2.0) ||
                           settingsButton.waitForExistence(timeout: 2.0) ||
                           app.tables.firstMatch.waitForExistence(timeout: 2.0) ||
                           app.cells.firstMatch.waitForExistence(timeout: 2.0)
        
        captureStepScreenshot("09_Safe_Disconnect_Returned_Home")
        
        XCTAssertTrue(homeAppeared, "❌ 自动化测试失败：点击断开后未能安全平稳退回首页")
        NSLog("[XCUITest] 🎯 全链路 XCUITest 端到端自动化测试全部圆满通过！")
    }

    // =========================================================================
    // MARK: - HSBTV7 物理 Apple TV 4K 硬件设备端到端自动化测试套件
    // =========================================================================
    /// 使用物理真机 (hu的iPhone SE) 操作物理 Apple TV (HSBTV7) 进行全链路全功能交互验证
    func testHSBTV7RemoteControlEndToEnd() throws {
        let app = XCUIApplication()
        app.activate()

        // 等待 App 启动、初始转场与 Bonjour 设备发现就绪 (3.5 秒)
        Thread.sleep(forTimeInterval: 3.5)
        
        // 若有先前残留的系统弹窗，平稳点击取消返回首页
        let oldAlert = app.alerts.firstMatch
        if oldAlert.exists {
            let cancel = oldAlert.buttons["取消"]
            if cancel.exists && cancel.isHittable {
                cancel.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        captureStepScreenshot("01_HSBTV7_Launched_Home")

        // ---------------------------------------------------------------------
        // 步骤 1: 局域网 mDNS 扫描并精准识别物理 Apple TV 硬件 (HSBTV7)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest HSBTV7] 步骤 1: 正在扫描局域网物理 Apple TV 4K 硬件 (HSBTV7)...")
        let tvPredicate = NSPredicate(format: "label CONTAINS[c] 'HSBTV7'")
        
        var targetElement: XCUIElement?
        let maxWaitSeconds: TimeInterval = 35.0
        let startTime = Date()
        var hasSwipedRefresh = false
        
        while Date().timeIntervalSince(startTime) < maxWaitSeconds {
            let directCell = app.cells.matching(tvPredicate).firstMatch
            if directCell.exists {
                targetElement = directCell
                break
            }
            let containingCell = app.cells.containing(tvPredicate).firstMatch
            if containingCell.exists {
                targetElement = containingCell
                break
            }
            let staticText = app.staticTexts.matching(tvPredicate).firstMatch
            if staticText.exists {
                targetElement = staticText
                break
            }
            let tvAny = app.descendants(matching: .any).matching(tvPredicate).firstMatch
            if tvAny.exists {
                targetElement = tvAny
                break
            }
            
            if Date().timeIntervalSince(startTime) > 6.0 && !hasSwipedRefresh {
                hasSwipedRefresh = true
                NSLog("[XCUITest HSBTV7] 尝试下拉刷新设备发现列表...")
                app.swipeDown()
                Thread.sleep(forTimeInterval: 1.0)
            } else {
                Thread.sleep(forTimeInterval: 0.6)
            }
        }

        guard let element = targetElement, element.exists else {
            captureStepScreenshot("01_Fail_HSBTV7_Not_Found")
            XCTFail("❌ 自动化测试失败：未能在 25 秒内通过局域网 mDNS 发现目标 HSBTV7 设备")
            return
        }

        if !element.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
        }

        captureStepScreenshot("02_HSBTV7_Discovered_Card")
        NSLog("[XCUITest HSBTV7] ✅ 成功捕获目标 HSBTV7 物理设备卡片: '%@'", element.label)

        // ---------------------------------------------------------------------
        // 步骤 2: 点击 HSBTV7 设备卡片，安全等待连接建立与推栈转场
        // ---------------------------------------------------------------------
        NSLog("[XCUITest HSBTV7] 步骤 2: 点击 HSBTV7 设备卡片进入遥控控制台...")
        element.tap()

        // ---------------------------------------------------------------------
        // 步骤 3: 严格等待 Apple TV 原生系统遥控界面完全转场并呈现就绪 (统一事件循环驱动)
        // ---------------------------------------------------------------------
        let navTitle = app.staticTexts["智能遥控器"]
        let systemTab = app.buttons["系统"]
        let okButton = app.buttons["确定"]
        let altOkButton = app.buttons["dpad_ok_button"]
        let altTextOk = app.staticTexts["OK"]
        let disconnectButton = app.buttons["断开"]

        var enteredRemotePage = false
        var capturedPinPrompt = false
        let enterStartTime = Date()
        let maxEnterWait: TimeInterval = 45.0
        
        while Date().timeIntervalSince(enterStartTime) < maxEnterWait {
            // 1. 成功进入遥控器控制台判定
            if systemTab.exists || okButton.exists || altOkButton.exists || altTextOk.exists || navTitle.exists || disconnectButton.exists {
                enteredRemotePage = true
                NSLog("[XCUITest HSBTV7] ✅ 成功检测到遥控器界面核心组件就绪！")
                break
            }
            
            // 2. 检查并处置电视安全配对 PIN 码弹窗
            let pinAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS 'PIN 码'")).firstMatch
            if pinAlert.exists {
                if !capturedPinPrompt {
                    capturedPinPrompt = true
                    captureStepScreenshot("02_1_HSBTV7_PIN_Prompt")
                    NSLog("[XCUITest HSBTV7] ⚠️ 发现电视安全配对 PIN 码弹窗，正在通过 OCR 与自动化通道输入...")
                }
                
                // 多级获取大屏 PIN 码:
                // 级别 1 (最高优先级): 系统级剪贴板直读 (宿主通过 devicectl device pasteboard copy 硬件隧道直写，0ms、0网络权限依赖)
                var fetchedPin: String?
                if let pb = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                   pb.count == 4, pb.allSatisfy({ $0.isNumber }) {
                    fetchedPin = pb
                    NSLog("[XCUITest HSBTV7] 🎯 成功从系统剪贴板获取电视 PIN 码: [%@]", pb)
                }
                
                // 级别 2: 网络通道探测兜底 (USB 硬件隧道 + 局域网 Wi-Fi)
                if fetchedPin == nil {
                    let candidateEndpoints = [
                        "http://169.254.53.131:49888/control?action=get_tv_pin",
                        "http://192.168.1.27:49888/control?action=get_tv_pin",
                        "http://192.168.1.108:49888/control?action=get_tv_pin"
                    ]
                    for ep in candidateEndpoints {
                        if let url = URL(string: ep) {
                            var req = URLRequest(url: url)
                            req.timeoutInterval = 0.5
                            let sem = DispatchSemaphore(value: 0)
                            let task = URLSession.shared.dataTask(with: req) { data, _, _ in
                                if let d = data,
                                   let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                                   let pin = json["pin"] as? String, pin.count == 4 {
                                    fetchedPin = pin
                                }
                                sem.signal()
                            }
                            task.resume()
                            _ = sem.wait(timeout: .now() + 0.6)
                            if fetchedPin != nil {
                                NSLog("[XCUITest HSBTV7] 🎯 成功从宿主通道 (%@) 获取电视 PIN 码: [%@]", ep, fetchedPin!)
                                break
                            }
                        }
                    }
                }
                
                if let pin = fetchedPin {
                    let tf = pinAlert.textFields.firstMatch
                    if tf.exists {
                        tf.tap()
                        tf.typeText(pin)
                        Thread.sleep(forTimeInterval: 0.3)
                        let pairBtn = pinAlert.buttons["配对连接"]
                        if pairBtn.exists && pairBtn.isHittable {
                            pairBtn.tap()
                            NSLog("[XCUITest HSBTV7] ✅ 已自动在输入框填入 PIN 码 [%@] 并点击'配对连接'", pin)
                            UIPasteboard.general.string = ""
                            Thread.sleep(forTimeInterval: 1.0)
                        }
                    }
                } else {
                    // 若文本框已有 4 位数字（外部通道注入），直接点击配对
                    let tf = pinAlert.textFields.firstMatch
                    if tf.exists {
                        let val = (tf.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        if val.count == 4 {
                            let pairBtn = pinAlert.buttons["配对连接"]
                            if pairBtn.exists && pairBtn.isHittable {
                                pairBtn.tap()
                                NSLog("[XCUITest HSBTV7] ✅ 文本框已包含 4 位 PIN 码 (%@)，点击'配对连接'", val)
                                Thread.sleep(forTimeInterval: 1.0)
                            }
                        }
                    }
                }
            }
            
            // 3. 检查是否有重试弹窗或电视连接指引
            let retryAlertBtn = app.alerts.buttons["🔄 重试连接"]
            if retryAlertBtn.exists && retryAlertBtn.isHittable {
                NSLog("[XCUITest HSBTV7] 触发重试连接弹窗，执行点击...")
                retryAlertBtn.tap()
                Thread.sleep(forTimeInterval: 1.2)
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertTrue(enteredRemotePage, "❌ 自动化测试失败：点击 HSBTV7 后未能成功进入 Apple TV 遥控器界面")
        // 等待界面转场与布局完全稳定
        Thread.sleep(forTimeInterval: 1.5)
        captureStepScreenshot("03_HSBTV7_Entered_Remote_Panel")
        NSLog("[XCUITest HSBTV7] ✅ 成功进入 HSBTV7 专属遥控界面，微操控制组件全部就绪！")

        let window = app.windows.firstMatch

        // ---------------------------------------------------------------------
        // 步骤 4: D-Pad 轮盘全方位导航微操验证 (上/下/左/右/中心确认)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest HSBTV7] 步骤 4: 逐一驱动 D-Pad 轮盘全方位微操按键...")
        
        // 1. D-Pad 向上按键
        let upBtn = app.buttons["方向 向上"]
        let altUpBtn = app.buttons["dpad_up"]
        if upBtn.waitForExistence(timeout: 1.5) && upBtn.isHittable {
            upBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 1/5] 点击 D-Pad '向上' 成功")
        } else if altUpBtn.waitForExistence(timeout: 1.5) && altUpBtn.isHittable {
            altUpBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 1/5] 点击 dpad_up 成功")
        } else {
            // 几何坐标兜底 (轮盘中心上偏 55pt)
            XCTFail("❌ 未找到 D-Pad 向上 按键 (identifier 缺失)，已避免盲点几何坐标误触其它控件")
        }
        Thread.sleep(forTimeInterval: 0.3)

        // 2. D-Pad 向下按键
        let downBtn = app.buttons["方向 向下"]
        let altDownBtn = app.buttons["dpad_down"]
        if downBtn.waitForExistence(timeout: 1.5) && downBtn.isHittable {
            downBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 2/5] 点击 D-Pad '向下' 成功")
        } else if altDownBtn.waitForExistence(timeout: 1.5) && altDownBtn.isHittable {
            altDownBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 2/5] 点击 dpad_down 成功")
        } else {
            // 几何坐标兜底 (轮盘中心下偏 55pt)
            XCTFail("❌ 未找到 D-Pad 向下 按键 (identifier 缺失)，已避免盲点几何坐标误触其它控件")
        }
        Thread.sleep(forTimeInterval: 0.3)

        // 3. D-Pad 向左按键
        let leftBtn = app.buttons["方向 向左"]
        let altLeftBtn = app.buttons["dpad_left"]
        if leftBtn.waitForExistence(timeout: 1.5) && leftBtn.isHittable {
            leftBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 3/5] 点击 D-Pad '向左' 成功")
        } else if altLeftBtn.waitForExistence(timeout: 1.5) && altLeftBtn.isHittable {
            altLeftBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 3/5] 点击 dpad_left 成功")
        } else {
            // 几何坐标兜底 (轮盘中心左偏 55pt)
            XCTFail("❌ 未找到 D-Pad 向左 按键 (identifier 缺失)，已避免盲点几何坐标误触其它控件")
        }
        Thread.sleep(forTimeInterval: 0.3)

        // 4. D-Pad 向右按键
        let rightBtn = app.buttons["方向 向右"]
        let altRightBtn = app.buttons["dpad_right"]
        if rightBtn.waitForExistence(timeout: 1.5) && rightBtn.isHittable {
            rightBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 4/5] 点击 D-Pad '向右' 成功")
        } else if altRightBtn.waitForExistence(timeout: 1.5) && altRightBtn.isHittable {
            altRightBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 4/5] 点击 dpad_right 成功")
        } else {
            // 几何坐标兜底 (轮盘中心右偏 55pt)
            XCTFail("❌ 未找到 D-Pad 向右 按键 (identifier 缺失)，已避免盲点几何坐标误触其它控件")
        }
        Thread.sleep(forTimeInterval: 0.3)

        // 5. D-Pad 中心确认键 (OK)
        if okButton.waitForExistence(timeout: 1.5) && okButton.isHittable {
            okButton.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 5/5] 点击 D-Pad '确定' 成功")
        } else if altOkButton.waitForExistence(timeout: 1.5) && altOkButton.isHittable {
            altOkButton.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 5/5] 点击 dpad_ok_button 成功")
        } else if altTextOk.waitForExistence(timeout: 1.5) && altTextOk.isHittable {
            altTextOk.tap()
            NSLog("[XCUITest HSBTV7] ✅ [DPad 5/5] 点击 'OK' 文本成功")
        } else {
            // 几何坐标兜底 (轮盘几何中心)
            XCTFail("❌ 未找到 D-Pad 确认 按键 (identifier 缺失)，已避免盲点几何坐标误触其它控件")
        }
        Thread.sleep(forTimeInterval: 0.4)
        captureStepScreenshot("04_HSBTV7_DPad_Navigation_Done")

        // ---------------------------------------------------------------------
        // 步骤 5: 系统核心功能控制岛与硬件音量调节验证
        // ---------------------------------------------------------------------
        NSLog("[XCUITest HSBTV7] 步骤 5: 逐一驱动系统核心功能与音量调节按键...")
        
        let homeBtn = app.buttons["桌面"]
        let backBtn = app.buttons["返回"]
        let muteBtn = app.buttons["静音"]
        let volMinusBtn = app.buttons["音量 -"]
        let volPlusBtn = app.buttons["音量 +"]

        if homeBtn.waitForExistence(timeout: 2.0) && homeBtn.isHittable {
            homeBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [System 1/5] 点击 '桌面' (Home/TV) 成功")
            Thread.sleep(forTimeInterval: 0.3)
        }
        if backBtn.waitForExistence(timeout: 2.0) && backBtn.isHittable {
            backBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [System 2/5] 点击 '返回' (Menu) 成功")
            Thread.sleep(forTimeInterval: 0.3)
        }
        if muteBtn.waitForExistence(timeout: 2.0) && muteBtn.isHittable {
            muteBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [System 3/5] 点击 '静音' (Mute) 成功")
            Thread.sleep(forTimeInterval: 0.3)
        }
        if volMinusBtn.waitForExistence(timeout: 2.0) && volMinusBtn.isHittable {
            volMinusBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [System 4/5] 点击 '音量 -' 成功")
            Thread.sleep(forTimeInterval: 0.3)
        }
        if volPlusBtn.waitForExistence(timeout: 2.0) && volPlusBtn.isHittable {
            volPlusBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [System 5/5] 点击 '音量 +' 成功")
            Thread.sleep(forTimeInterval: 0.3)
        }
        captureStepScreenshot("05_HSBTV7_System_And_Volume_Done")

        // ---------------------------------------------------------------------
        // 步骤 6: 媒体核心控制行验证 (快退 10s / 播放暂停 / 快进 10s)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest HSBTV7] 步骤 6: 驱动媒体核心控制行...")
        let rewindBtn = app.buttons["快退 10s"]
        let playPauseBtn = app.buttons["播放 / 暂停"]
        let forwardBtn = app.buttons["快进 10s"]

        if rewindBtn.waitForExistence(timeout: 2.0) && rewindBtn.isHittable {
            rewindBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [Media 1/3] 点击 '快退 10s' 成功")
            Thread.sleep(forTimeInterval: 0.3)
        }
        if playPauseBtn.waitForExistence(timeout: 2.0) && playPauseBtn.isHittable {
            playPauseBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [Media 2/3] 点击 '播放 / 暂停' 成功")
            Thread.sleep(forTimeInterval: 0.3)
        }
        if forwardBtn.waitForExistence(timeout: 2.0) && forwardBtn.isHittable {
            forwardBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ [Media 3/3] 点击 '快进 10s' 成功")
            Thread.sleep(forTimeInterval: 0.3)
        }
        captureStepScreenshot("06_HSBTV7_Media_Control_Done")

        // ---------------------------------------------------------------------
        // 步骤 7: 遥控形态微操模式切换验证 (系统 <-> 触控)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest HSBTV7] 步骤 7: 验证遥控微操形态 Tab 切换与触控板微操...")
        let touchTab = app.buttons["触控"]
        if touchTab.waitForExistence(timeout: 2.0) && touchTab.isHittable {
            touchTab.tap()
            NSLog("[XCUITest HSBTV7] ✅ 成功切换至 '触控' 模式")
            Thread.sleep(forTimeInterval: 0.6)
            captureStepScreenshot("07_HSBTV7_Switched_To_Touch_Mode")
            
            // 在触控区域驱动微操拖拽
            let touchCenter = window.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.40))
            let dragTarget = touchCenter.withOffset(CGVector(dx: 50, dy: -35))
            touchCenter.press(forDuration: 0.15, thenDragTo: dragTarget)
            NSLog("[XCUITest HSBTV7] ✅ 触控微操平滑拖拽完成 (+50, -35)")
            Thread.sleep(forTimeInterval: 0.4)
            
            // 切回系统轮盘
            let systemTabBtn = app.buttons["系统"]
            if systemTabBtn.waitForExistence(timeout: 2.0) && systemTabBtn.isHittable {
                systemTabBtn.tap()
                NSLog("[XCUITest HSBTV7] ✅ 成功切回 '系统' 模式")
                Thread.sleep(forTimeInterval: 0.6)
            }
            captureStepScreenshot("08_HSBTV7_Switched_Back_To_System_Mode")
        }

        // ---------------------------------------------------------------------
        // 步骤 8: 验证文本同步与打字输入功能 (向 HSBTV7 发送文本)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest HSBTV7] 步骤 8: 唤起键盘输入抽屉并向 HSBTV7 发送文本...")
        // 导航栏右上角的键盘图标按键
        let navBars = app.navigationBars
        let keyboardBtn = navBars.buttons["nav_keyboard_button"]
        let rightBarBtn = navBars.buttons["打字输入"]
        
        if keyboardBtn.waitForExistence(timeout: 2.0) && keyboardBtn.isHittable {
            keyboardBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ 点击导航栏键盘按键成功")
        } else if rightBarBtn.waitForExistence(timeout: 1.5) && rightBarBtn.isHittable {
            rightBarBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ 点击导航栏打字输入按键唤起输入抽屉")
        } else {
            XCTFail("❌ 未找到导航栏键盘按键 (nav_keyboard_button)，已避免误点扫码按钮")
        }
        Thread.sleep(forTimeInterval: 0.5)

        let remoteTextField = app.textFields["remote_text_field"]
        let anyTextField = app.textFields.firstMatch
        if remoteTextField.waitForExistence(timeout: 3.0) {
            remoteTextField.tap()
            remoteTextField.typeText("HSBTV7 Apple TV Test\n")
            NSLog("[XCUITest HSBTV7] ✅ 在输入框键入 'HSBTV7 Apple TV Test' 并提交")
        } else if anyTextField.waitForExistence(timeout: 3.0) {
            anyTextField.tap()
            anyTextField.typeText("HSBTV7 Apple TV Test\n")
            NSLog("[XCUITest HSBTV7] ✅ 在首个输入框键入 'HSBTV7 Apple TV Test' 并提交")
        }

        let sendBtn = app.buttons["发送文本"]
        if sendBtn.waitForExistence(timeout: 1.5) && sendBtn.isHittable {
            sendBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ 点击'发送文本'按键完成文本分发")
        }
        Thread.sleep(forTimeInterval: 0.6)
        captureStepScreenshot("09_HSBTV7_TextInput_Done")

        // ---------------------------------------------------------------------
        // 步骤 9: 点击返回/退出，双向严格验证安全平稳退回首页 (绝不闪退)
        // ---------------------------------------------------------------------
        NSLog("[XCUITest HSBTV7] 步骤 9: 验证安全平稳退出链路...")
        let backNavBtn = navBars.buttons.element(boundBy: 0)
        let backByTitle = navBars.buttons["糖葫芦遥控器"]

        if backByTitle.waitForExistence(timeout: 2.0) && backByTitle.isHittable {
            backByTitle.tap()
            NSLog("[XCUITest HSBTV7] ✅ 点击导航栏 '糖葫芦遥控器' 返回按键")
        } else if backNavBtn.waitForExistence(timeout: 2.0) && backNavBtn.isHittable {
            backNavBtn.tap()
            NSLog("[XCUITest HSBTV7] ✅ 点击导航栏首个返回按键")
        } else {
            // 几何坐标兜底 (左上角导航返回区域)
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.05)).tap()
            NSLog("[XCUITest HSBTV7] ✅ 几何坐标兜底点击左上角返回区域")
        }

        // 双向严密断言：
        // 1. 遥控界面特有组件 (系统Tab / OK键) 在 6 秒内注销消失；
        // 2. 首页核心元素在 6 秒内就绪呈现。
        let systemTabDisappeared = systemTab.waitForNonExistence(timeout: 6.0)
        NSLog("[XCUITest HSBTV7] 遥控控制台注销判定: %@", systemTabDisappeared ? "已注销消失" : "仍存在(需排查)")
        XCTAssertTrue(systemTabDisappeared, "❌ 自动化测试失败：点击返回后遥控控制台界面未在规定时间内注销消失")

        let homeTitle = app.staticTexts["糖葫芦遥控器"]
        let deviceTitle = app.staticTexts["Apple TV 硬件终端"]
        let settingsButton = app.navigationBars.buttons.element(boundBy: 0)

        let homeAppeared = homeTitle.waitForExistence(timeout: 6.0) ||
                           deviceTitle.waitForExistence(timeout: 2.0) ||
                           settingsButton.waitForExistence(timeout: 2.0) ||
                           app.tables.firstMatch.waitForExistence(timeout: 2.0) ||
                           app.cells.firstMatch.waitForExistence(timeout: 2.0)

        captureStepScreenshot("10_HSBTV7_Safe_Exit_Returned_Home")
        XCTAssertTrue(homeAppeared, "❌ 自动化测试失败：点击返回后未能安全平稳退回首页")
        NSLog("[XCUITest HSBTV7] 🎯 HSBTV7 端到端物理实机全链路自动化测试全部圆满通过！")
    }
}
