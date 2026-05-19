import Foundation
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
    
    /// HSBLocalLLMManager 会通过这个接口桥接物理下载与加载，真正下载 safetensors 权重分片
    @objc public func loadAndActivateModel(modelId: String, callback: @escaping (String, Double) -> Void) {
        Task { @MainActor in
            do {
                self.accumulatedText = "【🚀 启动 Apple MLX 原生神经网络物理下载与编译模块】\n"
                callback(self.accumulatedText, 0.0)
                
                let repoName: String
                if modelId.contains("gemma") {
                    repoName = "mlx-community/gemma-2b-it-4bit"
                } else {
                    repoName = "mlx-community/Qwen1.5-0.5B-Chat-4bit"
                }
                
                let config = ModelConfiguration(id: repoName)
                MLX.Memory.cacheLimit = 20 * 1024 * 1024
                
                // 1. 智能判定：优先进行 100% 纯本地离线极速加载，绝不发起任何 HuggingFace 握手网络请求
                let cache = HubCache.default
                if let repoId = Repo.ID(rawValue: repoName),
                   let commitHash = cache.resolveRevision(repo: repoId, kind: .model, ref: "main") {
                    let localModelDir = cache.snapshotsDirectory(repo: repoId, kind: .model).appendingPathComponent(commitHash)
                    let configJson = localModelDir.appendingPathComponent("config.json")
                    if FileManager.default.fileExists(atPath: configJson.path) {
                        self.accumulatedText += "【📦 本地离线优先】发现本地完整缓存数据，正在进行 100% 纯本地离线装载...\n"
                        callback(self.accumulatedText, 0.5)
                        
                        let container = try await LLMModelFactory.shared.loadContainer(
                            from: localModelDir,
                            using: #huggingFaceTokenizerLoader()
                        )
                        self.modelContainer = container
                        self.currentModelId = modelId
                        
                        self.accumulatedText += "\n✅ 端侧纯血 MLX 模型加载完毕！硬件就绪。\n"
                        callback(self.accumulatedText, 1.0)
                        return
                    }
                }
                
                // 2. 如果本地缓存不存在，直接抛出本地未激活/未下载的明确错误，绝不进行任何网络请求
                throw NSError(domain: "com.hsb.llm", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "本地模型数据未就绪。请前往 [设置 -> AI模型中心] 下载并激活当前模型。"
                ])
                
            } catch {
                self.accumulatedText += "\n❌ 原生 MLX 模型加载失败: \(error.localizedDescription)\n"
                callback(self.accumulatedText, 0.0)
            }
        }
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
            
            let promptTokens = try await container.perform { context in
                try context.tokenizer.applyChatTemplate(messages: messages)
            }
            let lmInput = LMInput(tokens: MLXArray(promptTokens))
            
            var generatedOutput = ""
            let stream = try await container.perform { context in
                try MLXLMCommon.generate(
                    input: lmInput,
                    parameters: generateParameters,
                    context: context
                )
            }
            
            for try await result in stream {
                switch result {
                case .chunk(let text):
                    generatedOutput += text
                    // 极致清爽流式返回：只将大模型产出的纯净译文/代码回调给外部，绝无任何中间编译或思考日志前缀
                    callback(generatedOutput, false)
                case .info(let stats):
                    // 依然在后台控制台打印详细底层物理信息供分析，不显示给用户
                    let logText = String(format: "【🏆 本地 MLX 推理成功】吞吐率: %.2f tokens/s", stats.tokensPerSecond)
                    print(logText)
                    callback(generatedOutput, true)
                case .toolCall(_):
                    break
                }
            }
        } catch {
            callback("❌ 本地物理大模型运算出错: \(error.localizedDescription)", true)
        }
    }
    
    private func loadAndActivateModelAsync(modelId: String) async throws {
        let repoName: String
        if modelId.contains("gemma") {
            repoName = "mlx-community/gemma-2b-it-4bit"
        } else {
            repoName = "mlx-community/Qwen1.5-0.5B-Chat-4bit"
        }
        
        MLX.Memory.cacheLimit = 20 * 1024 * 1024
        
        let cache = HubCache.default
        guard let repoId = Repo.ID(rawValue: repoName),
              let commitHash = cache.resolveRevision(repo: repoId, kind: .model, ref: "main") else {
            throw NSError(domain: "com.hsb.llm", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "本地模型数据未就绪。请前往 [设置 -> AI模型中心] 下载并激活当前模型。"
            ])
        }
        
        let localModelDir = cache.snapshotsDirectory(repo: repoId, kind: .model).appendingPathComponent(commitHash)
        let configJson = localModelDir.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configJson.path) else {
            throw NSError(domain: "com.hsb.llm", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "本地模型数据未就绪。请前往 [设置 -> AI模型中心] 下载并激活当前模型。"
            ])
        }
        
        let container = try await LLMModelFactory.shared.loadContainer(
            from: localModelDir,
            using: #huggingFaceTokenizerLoader()
        )
        self.modelContainer = container
        self.currentModelId = modelId
    }
    
    /// 物理检查本地沙盒缓存是否存在完整的 Safetensors 模型文件
    @objc(isModelDownloaded:)
    public func isModelDownloaded(modelId: String) -> Bool {
        let repoName: String
        if modelId.contains("gemma") {
            repoName = "mlx-community/gemma-2b-it-4bit"
        } else {
            repoName = "mlx-community/Qwen1.5-0.5B-Chat-4bit"
        }
        
        let cache = HubCache.default
        guard let repoId = Repo.ID(rawValue: repoName),
              let commitHash = cache.resolveRevision(repo: repoId, kind: .model, ref: "main") else {
            return false
        }
        
        let localModelDir = cache.snapshotsDirectory(repo: repoId, kind: .model).appendingPathComponent(commitHash)
        let configJson = localModelDir.appendingPathComponent("config.json")
        return FileManager.default.fileExists(atPath: configJson.path)
    }
}
