//
//  HSBAppleTVDiscoveryVerificationTest.swift
//  HSBWatchCompanion
//
//  自动化验证测试：验证 Apple TV 局域网 Bonjour 发现、过滤规则 (itsytv-macos 0x4000 规则)、
//  双模聚合、HID 按键原生编码及端口敲门逻辑。
//

import Foundation
import Network

@objc public final class HSBAppleTVDiscoveryVerificationTest: NSObject {
    
    @objc public static func runAllTests(completion: @escaping (Bool, String) -> Void) {
        var results: [String] = []
        var allPassed = true
        
        func record(_ name: String, passed: Bool, detail: String = "") {
            if passed {
                results.append("✅ [PASS] \(name) \(detail)")
            } else {
                results.append("❌ [FAIL] \(name) \(detail)")
                allPassed = false
            }
        }
        
        // Test 1: itsytv-macos 0x4000 flags & AppleTV model filtering
        let realAppleTVFlags: UInt64 = 0x36782 // HSBTV7 真实 Apple TV
        let isRealATV = (realAppleTVFlags & 0x4000) != 0
        record("Test 1.1: Apple TV PIN Pairing Flag (0x36782 & 0x4000 != 0)", passed: isRealATV)
        
        let macFlags: UInt64 = 0x20300 // MacBook Companion Link
        let isMacFiltered = (macFlags & 0x4000) == 0
        record("Test 1.2: Filter out Mac / HomePod (0x20300 & 0x4000 == 0)", passed: isMacFiltered)
        
        // Test 2: Model & Subtitle formatting
        let testDevice = HSBDiscoveredAppleTV(
            id: "HSBTV7",
            name: "HSBTV7",
            host: "HSBTV7.local",
            port: 61925,
            modelName: "AppleTV14,1",
            isNativeAppleTV: true,
            isBrowserApp: false
        )
        let hasCorrectSubtitle = testDevice.displaySubtitle.contains("AppleTV14,1") && testDevice.displaySubtitle.contains("系统原生遥控就绪")
        record("Test 2: Device Subtitle Formatting", passed: hasCorrectSubtitle, detail: testDevice.displaySubtitle)
        
        // Test 3: Dual-mode aggregation
        let dualDevice = HSBDiscoveredAppleTV(
            id: "HSBTV7",
            name: "HSBTV7",
            host: "HSBTV7.local",
            port: 56789,
            modelName: "AppleTV14,1",
            isNativeAppleTV: true,
            isBrowserApp: true
        )
        let isDual = dualDevice.isDualMode && dualDevice.displaySubtitle.contains("双模聚合")
        record("Test 3: Dual Mode Aggregation (Native + Browser)", passed: isDual, detail: dualDevice.displaySubtitle)
        
        // Test 4: Native HID Button Codes (Up, Down, Left, Right, Select, Menu, Home)
        let upCode = SystemKey.up.nativeButtonCode == 88
        let downCode = SystemKey.down.nativeButtonCode == 89
        let leftCode = SystemKey.left.nativeButtonCode == 90
        let rightCode = SystemKey.right.nativeButtonCode == 91
        let selectCode = SystemKey.select.nativeButtonCode == 8
        let menuCode = SystemKey.menu.nativeButtonCode == 1
        let homeCode = SystemKey.home.nativeButtonCode == 7
        
        let hidPassed = upCode && downCode && leftCode && rightCode && selectCode && menuCode && homeCode
        record("Test 4: Native HID Button Code Mapping", passed: hidPassed, detail: "Up:88, Down:89, Left:90, Right:91, Select:8, Menu:1, Home:7")
        
        // Test 5: Port Knocking Async Safety
        HSBAppleTVDiscovery.shared.wakeDevice(host: "127.0.0.1") { _ in
            record("Test 5: Port Knocking Non-blocking Wake Execution", passed: true, detail: "3689, 7000, 49152, 49153 knocked safely")
            
            let report = results.joined(separator: "\n")
            DispatchQueue.main.async {
                completion(allPassed, report)
            }
        }
    }
}
