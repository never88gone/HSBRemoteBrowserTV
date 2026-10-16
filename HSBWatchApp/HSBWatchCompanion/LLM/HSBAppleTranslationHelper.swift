//
//  HSBAppleTranslationHelper.swift
//  HSBWatchCompanion
//

import Foundation
import UIKit
import SwiftUI
#if canImport(Translation)
import Translation
#endif

#if canImport(Translation)
@available(iOS 18.0, *)
struct TranslationBridgeView: View {
    let text: String
    let configuration: TranslationSession.Configuration
    let onCompletion: (String?, Error?) -> Void
    
    var body: some View {
        Color.clear
            .translationTask(configuration) { session in
                do {
                    let response = try await session.translate(text)
                    onCompletion(response.targetText, nil)
                } catch {
                    onCompletion(nil, error)
                }
            }
    }
}
#endif

@objcMembers
public class HSBAppleTranslationHelper: NSObject {
    
    @objc public static func translate(
        text: String,
        sourceLanguage: String?,
        targetLanguage: String?,
        completion: @escaping (String?, Error?) -> Void
    ) {
        #if canImport(Translation)
        guard #available(iOS 18.0, *) else {
            completion(nil, NSError(domain: "HSBTranslation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Translation framework is only available on iOS 18.0 or later."]))
            return
        }
        
        let sourceCode = self.mapLanguageToCode(sourceLanguage)
        let targetCode = self.mapLanguageToCode(targetLanguage)
        
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                completion(nil, NSError(domain: "HSBTranslation", code: -2, userInfo: [NSLocalizedDescriptionKey: "No active window scene found to host translation."]))
                return
            }
            
            var source: Locale.Language? = nil
            if let src = sourceCode {
                source = Locale.Language(identifier: src)
            }
            var target: Locale.Language? = nil
            if let tgt = targetCode {
                target = Locale.Language(identifier: tgt)
            }
            
            // 创建一个独立的不可见临时 UIWindow，以此完全隔绝导航栏跳转引起的 UI 生命周期干扰
            let translationWindow = UIWindow(windowScene: windowScene)
            translationWindow.windowLevel = .normal - 1
            translationWindow.frame = CGRect(x: -10, y: -10, width: 1, height: 1)
            translationWindow.alpha = 0.01
            translationWindow.isHidden = false
            
            let config = TranslationSession.Configuration(source: source, target: target)
            var hostingController: UIHostingController<TranslationBridgeView>? = nil
            
            // 用局部变量强引用该 window，防止其生命周期在翻译完成前回调前被过早释放
            var strongWindow: UIWindow? = translationWindow
            
            let bridgeView = TranslationBridgeView(text: text, configuration: config) { translatedText, error in
                completion(translatedText, error)
                
                DispatchQueue.main.async {
                    hostingController?.view.removeFromSuperview()
                    hostingController = nil
                    strongWindow?.isHidden = true
                    strongWindow = nil
                }
            }
            
            hostingController = UIHostingController(rootView: bridgeView)
            hostingController?.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            hostingController?.view.alpha = 0.01
            hostingController?.view.isUserInteractionEnabled = false
            
            translationWindow.rootViewController = hostingController
        }
        #else
        completion(nil, NSError(domain: "HSBTranslation", code: -3, userInfo: [NSLocalizedDescriptionKey: "Apple Translation SDK is not available in this build."]))
        #endif
    }
    
    private static func mapLanguageToCode(_ language: String?) -> String? {
        guard let lang = language else { return nil }
        switch lang {
        case "Auto": return nil
        case "Chinese": return "zh-Hans"
        case "English": return "en-US"
        case "Japanese": return "ja-JP"
        case "Korean": return "ko-KR"
        case "French": return "fr-FR"
        case "German": return "de-DE"
        case "Spanish": return "es-ES"
        case "Russian": return "ru-RU"
        default: return nil
        }
    }
}
