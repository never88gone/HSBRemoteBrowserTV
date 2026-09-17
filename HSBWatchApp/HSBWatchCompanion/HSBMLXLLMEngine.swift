import Foundation
import UIKit
import SwiftUI
#if canImport(Translation)
import Translation
#endif
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

/// 纯原生端侧大语言模型物理运算引擎 (基于 Apple 官方 mlx-swift 框架)
@objcMembers
public class HSBMLXLLMEngine: NSObject {
    
    @objc public static let shared = HSBMLXLLMEngine()
    
    private var callback: ((String, Bool) -> Void)?
    private var accumulatedText: String = ""
    private var activeTask: Task<Void, Error>?
    
    // 原生 MLX 端侧模型容器，持有在 Unified Memory 中执行的神经网络权重张量
    private var modelContainer: ModelContainer?
    private var currentModelId: String = ""
    private var isGenerating = false
    
    // 保存上一个推理任务，用于串行链式排队加锁，防止多任务并发导致 Metal 发生 ASSERT/崩溃
    private var lastInferenceTask: Task<Void, Never>?
    
    public override init() {
        super.init()
        
        // 修复 iOS 模拟器环境异常：MLX 依赖的底层 C++ 库在沙盒中找不到 HOME 或 USER 时会抛出 basic_string(nullptr) libc++ hardening crash。
        #if targetEnvironment(simulator)
        if getenv("HOME") == nil {
            setenv("HOME", NSHomeDirectory(), 1)
        }
        if getenv("USER") == nil {
            setenv("USER", "simulator_user", 1)
        }
        if getenv("TMPDIR") == nil {
            setenv("TMPDIR", NSTemporaryDirectory(), 1)
        }
        #endif
    }
    
    /// 核心物理下载与加载接口：支持精确进度与错误上报，支持镜像源自动重试与完整性校验
    /// 核心物理下载与加载接口：支持精确进度与错误上报，支持镜像源自动重试与完整性校验 (支持指定 customHost)
    @objc(loadAndActivateModelWithModelId:customHost:callback:)
    public func loadAndActivateModel(modelId: String, customHost: String?, callback: @escaping (String, Double) -> Void) {
        Task { @MainActor in
            let repoName = getRepoName(from: modelId)
            self.accumulatedText = "【🚀 启动 Apple MLX 原生神经网络物理下载与编译模块】\n"
            callback(self.accumulatedText, 0.0)
            
            // 1. 智能判定：优先进行 100% 纯本地离线极速加载，绝不发起网络请求
            if self.isModelDownloaded(modelId: modelId) {
                let cache = HubCache.default
                if let repoId = Repo.ID(rawValue: repoName),
                   let commitHash = cache.resolveRevision(repo: repoId, kind: .model, ref: "main") {
                    let localModelDir = cache.snapshotsDirectory(repo: repoId, kind: .model).appendingPathComponent(commitHash)
                    do {
                        self.accumulatedText += "【📦 本地离线优先】发现完整本地模型缓存，正在装载到统一内存...\n"
                        callback(self.accumulatedText, 0.5)
                        
                        #if !targetEnvironment(simulator)
                        let container = try await LLMModelFactory.shared.loadContainer(
                            from: localModelDir,
                            using: #huggingFaceTokenizerLoader()
                        )
                        self.modelContainer = container
                        #endif
                        self.currentModelId = modelId
                        
                        self.accumulatedText += "\n✅ 端侧纯血 MLX 模型加载完毕！硬件就绪。\n"
                        callback(self.accumulatedText, 1.0)
                        return
                    } catch {
                        print("[HSBMLXLLMEngine] 本地缓存装载异常: \(error.localizedDescription)，准备重新拉取。")
                    }
                }
            }
            
            // 2. 物理下载阶段：构建配置与多源重试列表
            let config = ModelConfiguration(id: repoName)
            #if !targetEnvironment(simulator)
            MLX.Memory.cacheLimit = 20 * 1024 * 1024
            #endif
            
            let primaryHost: String
            let isSpecifiedHost: Bool
            if let customHost = customHost, !customHost.isEmpty {
                primaryHost = customHost
                isSpecifiedHost = !customHost.contains("hf-mirror.com")
            } else {
                primaryHost = self.getCustomHubHost(for: modelId)
                isSpecifiedHost = false
            }
            
            let hostsToTry: [String]
            if isSpecifiedHost {
                hostsToTry = [primaryHost]
            } else {
                let fallbackHost = (primaryHost.contains("hf-mirror.com")) ? "https://huggingface.co" : "https://hf-mirror.com"
                hostsToTry = [primaryHost, fallbackHost]
            }
            
            var lastError: Error? = nil
            var succeeded = false
            
            for (index, currentHost) in hostsToTry.enumerated() {
                do {
                    guard let hostURL = URL(string: currentHost) else { continue }
                    let hostLabel = currentHost.contains("mirror") ? "国内镜像源" : (isSpecifiedHost ? "指定端点" : "官方直连源")
                    self.accumulatedText += "正在桥接 [\(hostLabel): \(currentHost)] 拉取物理大模型张量...\n"
                    callback(self.accumulatedText, 0.05)
                    
                    let customHubClient = HubClient(host: hostURL)
                    
                    let downloadTask = Task {
                        try await resolve(
                            configuration: config,
                            from: #hubDownloader(customHubClient),
                            useLatest: false
                        ) { progress in
                            Task { @MainActor in
                                let fraction = max(0.02, min(0.99, progress.fractionCompleted))
                                let pct = fraction * 100
                                let progStr = String(format: "%.1f%%", pct)
                                callback("【物理大模型下载与校验进度】: \(progStr)", fraction)
                            }
                        }
                    }
                    
                    let timerTask = Task {
                        try await Task.sleep(nanoseconds: 3_500_000_000)
                        downloadTask.cancel()
                    }
                    
                    let resolved: ResolvedModelConfiguration
                    do {
                        resolved = try await downloadTask.value
                        timerTask.cancel()
                    } catch {
                        timerTask.cancel()
                        throw error
                    }
                    
                    // 物理校验：下载成功后验证核心权重是否存在
                    guard self.isModelDownloaded(modelId: modelId) else {
                        throw NSError(domain: "com.hsb.llm", code: -404, userInfo: [
                            NSLocalizedDescriptionKey: "模型权重文件校验失败，safetensors 数据不完整。"
                        ])
                    }
                    
                    #if !targetEnvironment(simulator)
                    let container = try await LLMModelFactory.shared.loadContainer(
                        from: resolved.modelDirectory,
                        using: #huggingFaceTokenizerLoader()
                    )
                    self.modelContainer = container
                    #endif
                    
                    self.currentModelId = modelId
                    self.accumulatedText += "\n✅ 端侧纯血 MLX 模型加载并挂载完毕！硬件就绪。\n"
                    callback(self.accumulatedText, 1.0)
                    succeeded = true
                    break
                    
                } catch {
                    lastError = error
                    let errStr = error.localizedDescription.lowercased()
                    let isNotFound = errStr.contains("404") || errStr.contains("not found") || errStr.contains("entry not found") || errStr.contains("nonexistent")
                    
                    if isNotFound {
                        self.accumulatedText += "⚠️ 远端模型仓库不存在 (HTTP 404 / Not Found)，无需重试备用源。\n"
                        break
                    }
                    
                    let isLast = (index == hostsToTry.count - 1)
                    if !isLast {
                        self.accumulatedText += "⚠️ 当前源连接异常 (\(error.localizedDescription))，正在自动切换备用源重试...\n"
                        callback(self.accumulatedText, 0.02)
                    }
                }
            }
            
            if !succeeded {
                let errDesc = lastError?.localizedDescription ?? "未知网络连接错误"
                self.accumulatedText += "\n❌ 原生 MLX 模型加载/下载失败: \(errDesc)\n"
                // 约定：使用 -1.0 明确标记下载失败，防止上层状态机停留在 Downloading 死锁
                callback(self.accumulatedText, -1.0)
            }
        }
    }
    
    @objc(loadAndActivateModelWithModelId:callback:)
    public func loadAndActivateModel(modelId: String, callback: @escaping (String, Double) -> Void) {
        self.loadAndActivateModel(modelId: modelId, customHost: nil, callback: callback)
    }
    
    /// 获取特定模型设定的自定义 Host，默认 fallback 到全局自定义 Host 或 hf-mirror.com
    private func getCustomHubHost(for modelId: String) -> String {
        if let modelHost = UserDefaults.standard.string(forKey: "HSBLocalLLM_ModelEndpoint_" + modelId), !modelHost.isEmpty {
            return modelHost
        }
        if let savedHost = UserDefaults.standard.string(forKey: "HSBLocalLLM_CustomHost"), !savedHost.isEmpty {
            return savedHost
        }
        return "https://hf-mirror.com"
    }
    
    @objc public func generateWithMLX(systemPrompt: String, userPrompt: String, modelId: String, callback: @escaping (String, Bool) -> Void) {
        let previousTask = self.lastInferenceTask
        
        let newTask = Task {
            // 1. 串行链式排队加锁：等待前一个推理任务彻底执行完成后才开启本次物理大模型生成，防范 Metal/GPU 碰撞崩溃
            _ = await previousTask?.result
            
            // 2. 极致清爽：开启本次物理大模型推理，全程静默（无任何思考或挂载提示词过程），直接将最干净的流式结果吐给 callback
            await self.performInference(systemPrompt: systemPrompt, userPrompt: userPrompt, modelId: modelId, callback: callback)
        }
        
        self.lastInferenceTask = newTask
    }
    
    private func performInference(systemPrompt: String, userPrompt: String, modelId: String, callback: @escaping (String, Bool) -> Void) async {
        #if targetEnvironment(simulator)
        // 模拟器环境安全保护：iOS 模拟器不具备 Apple Silicon 原生 Metal 物理神经网络硬件，自动返回降级标记
        callback("❌ [模拟器防护] 当前处于 iOS 模拟器环境，MLX 物理神经网络需真机运行。已自动为您无缝切换至端侧智能引擎响应。", true)
        return
        #else
        // 本地模型若未装载，则先以异步静默方式将其安全加载进 Unified Memory
        if self.modelContainer == nil || self.currentModelId != modelId {
            do {
                try await self.loadAndActivateModelAsync(modelId: modelId)
            } catch {
                callback("❌ 原生 MLX 模型加载失败: \(error.localizedDescription)", true)
                return
            }
        }
        
        guard let container = self.modelContainer else {
            callback("❌ 本地模型数据未就绪，请先前往 [设置 -> AI模型中心] 下载并激活当前模型。", true)
            return
        }
        
        do {
            let generateParameters = GenerateParameters(temperature: 0.3)
            let messages = [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
            
            // 安全构造输入 Tokens：优先使用 Chat Template，失败时自动降级编码
            let promptTokens: [Int] = try await container.perform { context in
                do {
                    return try context.tokenizer.applyChatTemplate(messages: messages)
                } catch {
                    let fallbackPrompt = "\(systemPrompt)\n\nUser: \(userPrompt)\n\nAssistant:"
                    return context.tokenizer.encode(text: fallbackPrompt)
                }
            }
            let lmInput = LMInput(tokens: MLXArray(promptTokens))
            
            var generatedOutput = ""
            var didReportFinished = false
            
            let stream = try await container.perform { context in
                try MLXLMCommon.generate(
                    input: lmInput,
                    parameters: generateParameters,
                    context: context
                )
            }
            
            for try await result in stream {
                if Task.isCancelled {
                    callback("❌ 推理任务已手动取消或超时中断", true)
                    didReportFinished = true
                    return
                }
                switch result {
                case .chunk(let text):
                    if Task.isCancelled {
                        callback("❌ 推理任务已手动取消或超时中断", true)
                        didReportFinished = true
                        return
                    }
                    generatedOutput += text
                    callback(generatedOutput, false)
                case .info(let stats):
                    let logText = String(format: "【🏆 本地 MLX 推理成功】吞吐率: %.2f tokens/s", stats.tokensPerSecond)
                    print(logText)
                    callback(generatedOutput, true)
                    didReportFinished = true
                case .toolCall(_):
                    break
                }
            }
            
            // 兜底保障：确保循环结束时始终触发 isFinished 回调
            if !didReportFinished {
                callback(generatedOutput.isEmpty ? "（模型推理已就绪，无文本产出）" : generatedOutput, true)
            }
        } catch {
            callback("❌ 本地物理大模型运算出错: \(error.localizedDescription)", true)
        }
        #endif
    }
    
    private func loadAndActivateModelAsync(modelId: String) async throws {
        #if targetEnvironment(simulator)
        return
        #else
        let repoName = getRepoName(from: modelId)
        
        MLX.Memory.cacheLimit = 20 * 1024 * 1024
        
        guard self.isModelDownloaded(modelId: modelId) else {
            throw NSError(domain: "com.hsb.llm", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "本地模型数据未就绪。请前往 [设置 -> AI模型中心] 下载并激活当前模型。"
            ])
        }
        
        let cache = HubCache.default
        guard let repoId = Repo.ID(rawValue: repoName),
              let commitHash = cache.resolveRevision(repo: repoId, kind: .model, ref: "main") else {
            throw NSError(domain: "com.hsb.llm", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "无法解析模型本地提交哈希。"
            ])
        }
        
        let localModelDir = cache.snapshotsDirectory(repo: repoId, kind: .model).appendingPathComponent(commitHash)
        let container = try await LLMModelFactory.shared.loadContainer(
            from: localModelDir,
            using: #huggingFaceTokenizerLoader()
        )
        self.modelContainer = container
        self.currentModelId = modelId
        #endif
    }
    
    /// 物理检查本地沙盒缓存是否存在完整的 Safetensors 模型文件与配置文件
    @objc(isModelDownloaded:)
    public func isModelDownloaded(modelId: String) -> Bool {
        let repoName = getRepoName(from: modelId)
        let cache = HubCache.default
        guard let repoId = Repo.ID(rawValue: repoName),
              let commitHash = cache.resolveRevision(repo: repoId, kind: .model, ref: "main") else {
            return false
        }
        
        let localModelDir = cache.snapshotsDirectory(repo: repoId, kind: .model).appendingPathComponent(commitHash)
        let configJson = localModelDir.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configJson.path) else {
            return false
        }
        
        // 校验是否存在至少一个非空的 safetensors 权重文件
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: localModelDir.path) else {
            return false
        }
        
        var hasValidSafetensors = false
        for file in files {
            if file.hasSuffix(".safetensors") {
                let filePath = localModelDir.appendingPathComponent(file).path
                if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                   let size = attrs[.size] as? NSNumber, size.int64Value > 1024 * 1024 { // 大于 1MB
                    hasValidSafetensors = true
                    break
                }
            }
        }
        return hasValidSafetensors
    }
    
    /// 检查大模型是否已经被成功载入内存中
    @objc public func isModelLoadedInMemory() -> Bool {
        return self.modelContainer != nil
    }
    
    /// 物理删除本地模型缓存以释放空间
    @objc public func deleteModelCache(modelId: String) -> Bool {
        let repoName = getRepoName(from: modelId)
        let cache = HubCache.default
        guard let repoId = Repo.ID(rawValue: repoName) else { return false }
        
        let repoDir = cache.repoDirectory(repo: repoId, kind: .model)
        let metaDir = cache.metadataDirectory(repo: repoId, kind: .model)
        
        var deleted = false
        if FileManager.default.fileExists(atPath: repoDir.path) {
            do {
                try FileManager.default.removeItem(at: repoDir)
                deleted = true
                print("[HSBMLXLLMEngine] 成功清除模型物理缓存: \(repoDir.path)")
            } catch {
                print("[HSBMLXLLMEngine] 清理模型缓存失败: \(error.localizedDescription)")
            }
        }
        
        if FileManager.default.fileExists(atPath: metaDir.path) {
            try? FileManager.default.removeItem(at: metaDir)
        }
        
        if self.currentModelId == modelId {
            self.modelContainer = nil
            self.currentModelId = ""
        }
        return deleted
    }
    
    /// 主动终止/取消当前的流式文本生成任务，切断 Metal / GPU 运算
    @objc public func cancelCurrentInference() {
        self.lastInferenceTask?.cancel()
        self.lastInferenceTask = nil
    }
}

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

fileprivate func getRepoName(from modelId: String) -> String {
    if modelId.contains("/") {
        return modelId
    } else if modelId.contains("gemma") {
        return "mlx-community/gemma-2-2b-it-4bit"
    } else {
        return "mlx-community/Qwen1.5-0.5B-Chat-4bit"
    }
}
