//
//  ModernLLMModelCenterView.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI AI 模型中心：
//  - 全面取代 HSBLLMModelCenterViewController & HSBLocalLLMModelCell；
//  - 支持端侧 MLX 大模型下载/暂停/继续/删除缓存、Apple 原生离线翻译引擎切换、自定义 OpenAI/DeepSeek/Ollama API 配置及自定义 HuggingFace Repo 导入；
//  - 在 iPhone Duo 展开态 (width >= 550pt) 下自动排版为双栏 Bento 智能控制台。
//

import SwiftUI
import Combine

public struct LLMDisplayModelItem: Identifiable {
    public let id: String
    public let modelId: String
    public let name: String
    public let description: String
    public let status: HSBLocalLLMDownloadStatus
    public let progress: Double
    public let isActive: Bool
    public let isJSActive: Bool
    public let rawModel: HSBLocalLLMModel?
}

@MainActor
public final class ModernLLMModelCenterViewModel: ObservableObject {
    @Published public var models: [LLMDisplayModelItem] = []
    @Published public var engineDisplayName: String = ""
    @Published public var isBuiltInEngineActive: Bool = true
    @Published public var useAppleTranslation: Bool = true
    @Published public var useCustomAPI: Bool = false
    @Published public var customAPIEndpoint: String = ""
    @Published public var customAPIKey: String = ""
    @Published public var customAPIModel: String = ""
    
    @Published public var alertTitle: String = ""
    @Published public var alertMessage: String = ""
    @Published public var showingInfoAlert: Bool = false
    @Published public var failedModelToRetry: HSBLocalLLMModel?
    @Published public var showingRetryAlert: Bool = false
    
    private let isPreviewMock: Bool
    private var cancellables = Set<AnyCancellable>()
    
    public init(isPreviewMock: Bool = false) {
        self.isPreviewMock = isPreviewMock
        if isPreviewMock {
            loadMockState()
        } else {
            refreshFromManager()
            setupNotifications()
        }
    }
    
    private func setupNotifications() {
        let nc = NotificationCenter.default
        nc.publisher(for: Notification.Name("HSBLocalLLMDownloadProgressNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshFromManager() }
            .store(in: &cancellables)
        
        nc.publisher(for: Notification.Name("HSBLocalLLMDownloadFinishedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshFromManager() }
            .store(in: &cancellables)
        
        nc.publisher(for: Notification.Name("HSBLocalLLMDownloadFailedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self = self else { return }
                self.refreshFromManager()
                if let failed = note.object as? HSBLocalLLMModel {
                    self.failedModelToRetry = failed
                    self.alertTitle = hsbL("Download Failed", "模型下载失败")
                    self.alertMessage = (note.userInfo?["error"] as? String)
                        ?? hsbL("Network connection interrupted during weight download.", "下载权重文件时网络连接中断，请检查网络或镜像站状态。")
                    self.showingRetryAlert = true
                }
            }
            .store(in: &cancellables)
    }
    
    public func refreshFromManager() {
        guard !isPreviewMock else { return }
        let mgr = HSBLocalLLMManager.shared()
        self.engineDisplayName = mgr.currentEngineDisplayName
        self.isBuiltInEngineActive = mgr.isBuiltInEngineActive
        self.useAppleTranslation = HSBLocalLLMManager.useAppleTranslation()
        self.useCustomAPI = HSBLocalLLMManager.useCustomAPI()
        self.customAPIEndpoint = HSBLocalLLMManager.customAPIEndpoint()
        self.customAPIKey = HSBLocalLLMManager.customAPIKey()
        self.customAPIModel = HSBLocalLLMManager.customAPIModel()
        
        self.models = mgr.availableModels.map { model in
            LLMDisplayModelItem(
                id: model.modelId,
                modelId: model.modelId,
                name: model.name,
                description: model.modelDescription,
                status: model.status,
                progress: model.downloadProgress,
                isActive: model.isActive,
                isJSActive: model.isJSActive,
                rawModel: model
            )
        }
    }
    
    public func setUseAppleTranslation(_ value: Bool) {
        if isPreviewMock {
            useAppleTranslation = value
            return
        }
        HSBLocalLLMManager.setUseAppleTranslation(value)
        refreshFromManager()
    }
    
    public func setUseCustomAPI(_ value: Bool) {
        if isPreviewMock {
            useCustomAPI = value
            return
        }
        HSBLocalLLMManager.setUseCustomAPI(value)
        refreshFromManager()
    }
    
    public func saveCustomAPI(endpoint: String, apiKey: String, model: String) {
        if isPreviewMock {
            customAPIEndpoint = endpoint
            customAPIKey = apiKey
            customAPIModel = model
            useCustomAPI = true
            return
        }
        HSBLocalLLMManager.setCustomAPIEndpoint(endpoint)
        HSBLocalLLMManager.setCustomAPIKey(apiKey)
        HSBLocalLLMManager.setCustomAPIModel(model)
        HSBLocalLLMManager.setUseCustomAPI(true)
        refreshFromManager()
    }
    
    public func addCustomModel(name: String, repoId: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRepo = repoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedRepo.isEmpty else {
            presentAlert(title: hsbL("Invalid Input", "输入不完整"), message: hsbL("Please enter both model name and HuggingFace Repo ID.", "请填写完整的模型展示名称与 Repo ID。"))
            return
        }
        if isPreviewMock {
            models.append(
                LLMDisplayModelItem(
                    id: trimmedRepo,
                    modelId: trimmedRepo,
                    name: trimmedName,
                    description: trimmedRepo,
                    status: .none,
                    progress: 0,
                    isActive: false,
                    isJSActive: false,
                    rawModel: nil
                )
            )
            return
        }
        do {
            try HSBLocalLLMManager.shared().addCustomModel(withName: trimmedName, repoId: trimmedRepo)
            refreshFromManager()
        } catch {
            presentAlert(
                title: hsbL("Add Failed", "添加模型失败"),
                message: error.localizedDescription
            )
        }
    }
    
    public func handlePrimaryAction(for item: LLMDisplayModelItem) {
        guard let model = item.rawModel else { return }
        let mgr = HSBLocalLLMManager.shared()
        let isCurrentlyActive = useAppleTranslation ? model.isJSActive : model.isActive
        
        if isCurrentlyActive {
            if useAppleTranslation {
                mgr.deactivateJSModel(model)
            } else {
                mgr.deactivate(model)
            }
            refreshFromManager()
            return
        }
        
        switch model.status {
        case .finished:
            if useAppleTranslation {
                mgr.activateJSModel(model)
            } else {
                mgr.activate(model)
            }
            refreshFromManager()
        case .downloading:
            mgr.pauseDownloadModel(model)
            refreshFromManager()
        case .none, .paused, .failed:
            mgr.downloadModel(model, progress: { [weak self] _ in
                DispatchQueue.main.async { self?.refreshFromManager() }
            }, completion: { [weak self] _, _ in
                DispatchQueue.main.async { self?.refreshFromManager() }
            })
            refreshFromManager()
        @unknown default:
            break
        }
    }
    
    public func deleteCache(for item: LLMDisplayModelItem) {
        guard let model = item.rawModel else { return }
        let ok = HSBLocalLLMManager.shared().deleteModelCache(for: model)
        refreshFromManager()
        if !ok {
            presentAlert(title: hsbL("Notice", "提示"), message: hsbL("No local weight cache to clear.", "该模型暂无已占用的本地缓存文件。"))
        }
    }
    
    public func retryFailedDownload() {
        guard let model = failedModelToRetry else { return }
        failedModelToRetry = nil
        HSBLocalLLMManager.shared().downloadModel(model, progress: { [weak self] _ in
            DispatchQueue.main.async { self?.refreshFromManager() }
        }, completion: { [weak self] _, _ in
            DispatchQueue.main.async { self?.refreshFromManager() }
        })
        refreshFromManager()
    }
    
    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingInfoAlert = true
    }
    
    private func loadMockState() {
        engineDisplayName = "Qwen2.5-1.5B-Instruct (端侧 MLX)"
        isBuiltInEngineActive = false
        useAppleTranslation = true
        useCustomAPI = false
        customAPIEndpoint = "https://api.deepseek.com/v1"
        customAPIModel = "deepseek-chat"
        models = [
            LLMDisplayModelItem(
                id: "qwen2.5-1.5b",
                modelId: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
                name: "Qwen2.5-1.5B-Instruct (4bit)",
                description: "轻量高速多语言推理模型 · 极低内存占用 (~920 MB)",
                status: .finished,
                progress: 1.0,
                isActive: true,
                isJSActive: true,
                rawModel: nil
            ),
            LLMDisplayModelItem(
                id: "qwen2.5-3b",
                modelId: "mlx-community/Qwen2.5-3B-Instruct-4bit",
                name: "Qwen2.5-3B-Instruct (4bit)",
                description: "高准确度同声传译与网页智能脚本生成 (~1.85 GB)",
                status: .downloading,
                progress: 0.56,
                isActive: false,
                isJSActive: false,
                rawModel: nil
            ),
            LLMDisplayModelItem(
                id: "llama3.2-1b",
                modelId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                name: "Llama-3.2-1B-Instruct (4bit)",
                description: "Meta 超轻量化英文交互助手 · 毫秒首字响应 (~680 MB)",
                status: .none,
                progress: 0,
                isActive: false,
                isJSActive: false,
                rawModel: nil
            )
        ]
    }
}

public struct ModernLLMModelCenterView: View {
    @StateObject private var viewModel: ModernLLMModelCenterViewModel
    private let onOpenLab: () -> Void
    
    @State private var showingAPIConfigSheet: Bool = false
    @State private var showingAddModelSheet: Bool = false
    @State private var modelPendingDelete: LLMDisplayModelItem?
    
    // Form temp states
    @State private var endpointDraft: String = ""
    @State private var apiKeyDraft: String = ""
    @State private var modelDraft: String = ""
    @State private var customNameDraft: String = ""
    @State private var customRepoDraft: String = ""
    
    public init(isPreviewMock: Bool = false, onOpenLab: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: ModernLLMModelCenterViewModel(isPreviewMock: isPreviewMock))
        self.onOpenLab = onOpenLab
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let isWideDuo = geometry.size.width >= 550
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if isWideDuo {
                        // 宽屏展开顶部双卡并排
                        HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
                            engineStatusCard
                                .frame(width: DuoMetrics.columnWidth(for: geometry.size.width))
                            
                            VStack(spacing: 12) {
                                appleTranslationCard
                                customAPICard
                            }
                            .frame(width: DuoMetrics.columnWidth(for: geometry.size.width))
                        }
                    } else {
                        engineStatusCard
                        appleTranslationCard
                        customAPICard
                    }
                    
                    modelsSectionHeader
                    
                    let columns = isWideDuo
                        ? [GridItem(.flexible(), spacing: DuoMetrics.columnGap), GridItem(.flexible(), spacing: DuoMetrics.columnGap)]
                        : [GridItem(.flexible())]
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.models) { item in
                            modelCard(item)
                        }
                    }
                }
                .padding(.leading, isWideDuo ? DuoMetrics.outerPadding : 16)
                .padding(.trailing, isWideDuo ? DuoMetrics.trailingPadding : 16)
                .padding(.vertical, 16)
            }
            .background(DuoPalette.canvasBg.ignoresSafeArea())
        }
        .navigationTitle(hsbL("AI Model Center", "AI 模型中心"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(hsbL("API", "API配置")) {
                    endpointDraft = viewModel.customAPIEndpoint
                    apiKeyDraft = viewModel.customAPIKey
                    modelDraft = viewModel.customAPIModel
                    showingAPIConfigSheet = true
                }
                Button(hsbL("Add", "添加模型")) {
                    customNameDraft = ""
                    customRepoDraft = ""
                    showingAddModelSheet = true
                }
            }
        }
        .onAppear {
            viewModel.refreshFromManager()
        }
        .sheet(isPresented: $showingAPIConfigSheet) {
            customAPIConfigSheet
        }
        .sheet(isPresented: $showingAddModelSheet) {
            addCustomModelSheet
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showingInfoAlert) {
            Button(hsbL("OK", "知道了"), role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showingRetryAlert) {
            Button(hsbL("Retry", "🔄 重试下载")) {
                viewModel.retryFailedDownload()
            }
            Button(hsbL("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .confirmationDialog(
            hsbL("Delete Local Model Cache?", "删除本地大模型权重缓存？"),
            isPresented: Binding(
                get: { modelPendingDelete != nil },
                set: { if !$0 { modelPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(hsbL("Delete Cache", "删除缓存释放空间"), role: .destructive) {
                if let target = modelPendingDelete {
                    viewModel.deleteCache(for: target)
                }
                modelPendingDelete = nil
            }
            Button(hsbL("Cancel", "取消"), role: .cancel) {
                modelPendingDelete = nil
            }
        } message: {
            if let target = modelPendingDelete {
                Text("将清空【\(target.name)】占用的沙盒磁盘空间，不影响其他模型。")
            }
        }
    }
    
    // MARK: - 顶部主引擎卡片
    private var engineStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DuoPalette.brandPurple.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DuoPalette.brandPurple)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前 AI 引擎状态")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DuoPalette.textSecondary)
                    Text(viewModel.engineDisplayName.isEmpty ? "Apple 内置离线大模型" : viewModel.engineDisplayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DuoPalette.textPrimary)
                        .lineLimit(2)
                }
                Spacer()
            }
            
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DuoPalette.readyGreen)
                Text(
                    viewModel.isBuiltInEngineActive
                        ? "内置开箱即用零权重占用"
                        : "端侧独立推理大模型已激活"
                )
                .font(.system(size: 12.5))
                .foregroundColor(DuoPalette.textSecondary)
                Spacer()
            }
            
            Button(action: onOpenLab) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("打开端侧大模型实测实验室")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DuoPalette.brandBlue.opacity(0.9))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    // MARK: - 苹果原生翻译开关卡
    private var appleTranslationCard: some View {
        Toggle(
            isOn: Binding(
                get: { viewModel.useAppleTranslation },
                set: { viewModel.setUseAppleTranslation($0) }
            )
        ) {
            HStack(spacing: 10) {
                Image(systemName: "translate")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DuoPalette.brandBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("使用 Apple 原生翻译框架")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(DuoPalette.textPrimary)
                    Text(
                        viewModel.useAppleTranslation
                            ? "系统离线同传翻译 · 端侧模型专职 JS 控屏"
                            : "关闭后由激活的本地大模型同时接管翻译"
                    )
                    .font(.system(size: 11.5))
                    .foregroundColor(DuoPalette.textSecondary)
                }
            }
        }
        .tint(DuoPalette.readyGreen)
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    // MARK: - 自定义 API 开关与配置卡
    private var customAPICard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.useCustomAPI },
                    set: { viewModel.setUseCustomAPI($0) }
                )
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DuoPalette.warmOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用自定义云端/局域网 API")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundColor(DuoPalette.textPrimary)
                        Text(
                            viewModel.useCustomAPI
                                ? "\(viewModel.customAPIModel.isEmpty ? "未设模型" : viewModel.customAPIModel) · \(viewModel.customAPIEndpoint)"
                                : "兼容 OpenAI / DeepSeek / Ollama 零本地权重"
                        )
                        .font(.system(size: 11.5))
                        .foregroundColor(DuoPalette.textSecondary)
                        .lineLimit(1)
                    }
                }
            }
            .tint(DuoPalette.warmOrange)
            
            Button {
                endpointDraft = viewModel.customAPIEndpoint
                apiKeyDraft = viewModel.customAPIKey
                modelDraft = viewModel.customAPIModel
                showingAPIConfigSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                    Text("配置 API Endpoint 与密钥")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundColor(DuoPalette.warmOrange)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    // MARK: - 大模型列表头部
    private var modelsSectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    viewModel.useAppleTranslation
                        ? "电视控制 JS 脚本生成专用大模型 (端侧 MLX)"
                        : "通用端侧大模型矩阵 (翻译与 JS 共用)"
                )
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DuoPalette.textPrimary)
                
                Text("长按或点击右上垃圾桶可清理已下载模型的离线缓存")
                    .font(.system(size: 11.5))
                    .foregroundColor(DuoPalette.textMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - 单个模型卡片
    private func modelCard(_ item: LLMDisplayModelItem) -> some View {
        let isCurrentlyActive = viewModel.useAppleTranslation ? item.isJSActive : item.isActive
        let tint: Color = isCurrentlyActive ? DuoPalette.readyGreen : (item.status == .downloading ? DuoPalette.brandBlue : DuoPalette.textSecondary)
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundColor(DuoPalette.textPrimary)
                            .lineLimit(1)
                        
                        if isCurrentlyActive {
                            Text("运行中")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(DuoPalette.readyGreen))
                        }
                    }
                    
                    Text(item.description)
                        .font(.system(size: 12.5))
                        .foregroundColor(DuoPalette.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if item.status == .finished {
                    Button {
                        modelPendingDelete = item
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(DuoPalette.textMuted)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if item.status == .downloading || item.status == .paused {
                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(value: max(0, min(1, item.progress)))
                        .tint(item.status == .paused ? DuoPalette.warmOrange : DuoPalette.brandBlue)
                    Text(
                        item.status == .paused
                            ? "已暂停下载 (\(Int(item.progress * 100))%)"
                            : "正在高速拉取权重 (\(Int(item.progress * 100))%)"
                    )
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(DuoPalette.textSecondary)
                }
            }
            
            HStack {
                statusLabel(for: item, isCurrentlyActive: isCurrentlyActive, tint: tint)
                Spacer()
                Button {
                    viewModel.handlePrimaryAction(for: item)
                } label: {
                    Text(actionButtonTitle(for: item, isCurrentlyActive: isCurrentlyActive))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(actionButtonColor(for: item, isCurrentlyActive: isCurrentlyActive))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .duoCard(
            cornerRadius: DuoMetrics.innerCardRadius,
            stroke: isCurrentlyActive ? DuoPalette.readyGreen.opacity(0.55) : DuoPalette.stroke
        )
    }
    
    private func statusLabel(for item: LLMDisplayModelItem, isCurrentlyActive: Bool, tint: Color) -> some View {
        let text: String = {
            if isCurrentlyActive { return "已激活用于端侧推理" }
            switch item.status {
            case .finished: return "本地权重已就绪"
            case .downloading: return "拉取下载中"
            case .paused: return "断点续传待继续"
            case .failed: return "下载中断失败"
            default: return "未下载权重"
            }
        }()
        return Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(tint)
    }
    
    private func actionButtonTitle(for item: LLMDisplayModelItem, isCurrentlyActive: Bool) -> String {
        if isCurrentlyActive { return "停用" }
        switch item.status {
        case .finished: return viewModel.useAppleTranslation ? "设为 JS 模型" : "激活使用"
        case .downloading: return "暂停"
        case .paused: return "继续"
        case .failed: return "重试"
        default: return "下载"
        }
    }
    
    private func actionButtonColor(for item: LLMDisplayModelItem, isCurrentlyActive: Bool) -> Color {
        if isCurrentlyActive { return DuoPalette.hawthornRed }
        switch item.status {
        case .finished: return DuoPalette.readyGreen
        case .downloading: return DuoPalette.warmOrange
        case .failed: return DuoPalette.accentRed
        default: return DuoPalette.brandBlue
        }
    }
    
    // MARK: - Sheets
    private var customAPIConfigSheet: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("接口连接参数"),
                    footer: Text("兼容 OpenAI / DeepSeek / Ollama / LM Studio，开启后无需下载本地模型权重。")
                ) {
                    TextField("API Endpoint", text: $endpointDraft)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("API Key (可选本地局域网可留空)", text: $apiKeyDraft)
                    TextField("Model Name (例如 deepseek-chat)", text: $modelDraft)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("自定义大模型 API 配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { showingAPIConfigSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存并启用") {
                        viewModel.saveCustomAPI(endpoint: endpointDraft, apiKey: apiKeyDraft, model: modelDraft)
                        showingAPIConfigSheet = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var addCustomModelSheet: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("自定义 HuggingFace MLX 权重仓库"),
                    footer: Text("例如：mlx-community/Qwen2.5-1.5B-Instruct-4bit")
                ) {
                    TextField("模型展示名称", text: $customNameDraft)
                    TextField("HuggingFace Repo ID", text: $customRepoDraft)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("添加自定义 MLX 大模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { showingAddModelSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导入仓库") {
                        viewModel.addCustomModel(name: customNameDraft, repoId: customRepoDraft)
                        showingAddModelSheet = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
#Preview("AI 模型中心 · 折叠窄屏") {
    DuoPreviewContainer("AI 模型中心", expandedDuo: false) {
        ModernLLMModelCenterView(isPreviewMock: true) {}
    }
}

#Preview("AI 模型中心 · iPhone Duo 双栏展开") {
    DuoPreviewContainer("AI 模型中心", expandedDuo: true) {
        ModernLLMModelCenterView(isPreviewMock: true) {}
    }
}
#endif
