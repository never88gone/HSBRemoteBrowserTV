//
//  ModernLLMTestView.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI 端侧大模型实验室与同声传译测试面板：
//  - 全面替代 HSBLLMTestViewController、HSBLLMStatusCardView、HSBLLMInputPanel 与 HSBLLMResultCardView；
//  - 支持同声传译、电视控制脚本生成、智能管家三大核心场景；
//  - 支持 iPhone Duo 展开态 (width >= 550pt) 左右对称分栏展示。
//

import SwiftUI
import UIKit
import Combine

@MainActor
public final class ModernLLMTestViewModel: ObservableObject {
    @Published public var scenario: HSBLLMTestScenarioType = .translation {
        didSet { refreshScenarioMetadata() }
    }
    @Published public var inputText: String = ""
    @Published public var outputText: String = ""
    @Published public var isGenerating: Bool = false
    @Published public var engineTitle: String = ""
    @Published public var quickTags: [String] = []
    @Published public var inputPlaceholder: String = ""
    @Published public var sourceLanguageKey: String = "Auto"
    @Published public var targetLanguageKey: String = "Chinese"
    
    private let isPreviewMock: Bool
    private var cancellables = Set<AnyCancellable>()
    
    public init(isPreviewMock: Bool = false) {
        self.isPreviewMock = isPreviewMock
        self.sourceLanguageKey = UserDefaults.standard.string(forKey: "HSBTranslationSourceLanguage") ?? "Auto"
        self.targetLanguageKey = UserDefaults.standard.string(forKey: "HSBTranslationTargetLanguage") ?? "Chinese"
        
        if isPreviewMock {
            self.engineTitle = "Apple 原生离线翻译 / MLX-Qwen2.5-1.5B"
            self.quickTags = ["欢迎使用糖葫芦遥控器", "明天早晨会有小雨吗", "帮我总结这段新闻"]
            self.inputPlaceholder = "请输入待实时同声传译的句子或段落..."
            self.inputText = "Welcome to Tanghulu TV Browser with dual-screen control!"
            self.outputText = "欢迎使用具备双屏协同控制能力的糖葫芦大屏浏览器！"
        } else {
            refreshStatusAndMetadata()
            NotificationCenter.default.publisher(for: Notification.Name("HSBLocalLLMDownloadFinishedNotification"))
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.refreshStatusAndMetadata() }
                .store(in: &cancellables)
        }
    }
    
    public func refreshStatusAndMetadata() {
        guard !isPreviewMock else { return }
        engineTitle = HSBLocalLLMManager.shared().currentEngineDisplayName
        refreshScenarioMetadata()
    }
    
    private func refreshScenarioMetadata() {
        guard !isPreviewMock else { return }
        let promptMgr = HSBLLMPromptManager.shared()
        quickTags = promptMgr.quickPromptTags(for: scenario)
        inputPlaceholder = promptMgr.placeholderText(for: scenario)
    }
    
    public func applyQuickTag(at index: Int) {
        if isPreviewMock {
            if index < quickTags.count {
                inputText = quickTags[index]
            }
            return
        }
        inputText = HSBLLMPromptManager.shared().promptText(for: scenario, at: index)
    }
    
    public func supportedLanguages(isSource: Bool) -> [String] {
        if isPreviewMock {
            return isSource ? ["自动检测", "中文", "英文", "日文"] : ["中文", "英文", "日文"]
        }
        return HSBLLMPromptManager.shared().supportedLanguages(forSource: isSource)
    }
    
    public func languageDisplayName(forKey key: String) -> String {
        if isPreviewMock {
            return key == "Auto" ? "自动检测" : (key == "Chinese" ? "中文" : key)
        }
        return HSBLLMPromptManager.shared().languageName(forKey: key)
    }
    
    public func selectLanguage(displayName: String, isSource: Bool) {
        let key = isPreviewMock ? displayName : HSBLLMPromptManager.shared().languageKey(forName: displayName)
        if isSource {
            sourceLanguageKey = key
            UserDefaults.standard.set(key, forKey: "HSBTranslationSourceLanguage")
        } else {
            targetLanguageKey = key
            UserDefaults.standard.set(key, forKey: "HSBTranslationTargetLanguage")
        }
    }
    
    public func sendOrStop() {
        if isGenerating {
            if !isPreviewMock {
                HSBLocalLLMManager.shared().cancelInference()
            }
            isGenerating = false
            return
        }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if isPreviewMock {
            outputText = "正在为您处理：\(trimmed)"
            return
        }
        
        isGenerating = true
        outputText = ""
        
        let promptMgr = HSBLLMPromptManager.shared()
        let taskType: Int = (scenario == .webControl) ? 2 : (scenario == .smartButler ? 3 : 1)
        let sysPrompt = promptMgr.systemPrompt(for: scenario)
        let enhancedPrompt = promptMgr.enhancedUserPrompt(
            for: scenario,
            userPrompt: trimmed,
            sourceLanguage: sourceLanguageKey,
            targetLanguage: targetLanguageKey
        )
        
        HSBLocalLLMManager.shared().processMessage(
            enhancedPrompt,
            systemPrompt: sysPrompt,
            type: taskType
        ) { [weak self] response, isFinished in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.outputText = response
                if isFinished {
                    self.isGenerating = false
                }
            }
        }
    }
}

public struct ModernLLMTestView: View {
    @StateObject private var viewModel: ModernLLMTestViewModel
    private let onOpenModelCenter: () -> Void
    @State private var copiedToastVisible: Bool = false
    
    public init(isPreviewMock: Bool = false, onOpenModelCenter: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: ModernLLMTestViewModel(isPreviewMock: isPreviewMock))
        self.onOpenModelCenter = onOpenModelCenter
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let isWideDuo = geometry.size.width >= 550
            ScrollView(showsIndicators: false) {
                if isWideDuo {
                    HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
                        VStack(spacing: 14) {
                            statusBannerCard
                            scenarioAndLanguageCard
                            inputConsoleCard
                        }
                        .frame(width: DuoMetrics.columnWidth(for: geometry.size.width))
                        
                        resultOutputCard
                            .frame(width: DuoMetrics.columnWidth(for: geometry.size.width))
                    }
                    .padding(.leading, DuoMetrics.outerPadding)
                    .padding(.trailing, DuoMetrics.trailingPadding)
                    .padding(.vertical, 16)
                } else {
                    VStack(spacing: 16) {
                        statusBannerCard
                        scenarioAndLanguageCard
                        inputConsoleCard
                        resultOutputCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .background(DuoPalette.canvasBg.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                if copiedToastVisible {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DuoPalette.readyGreen)
                        Text(hsbL("Copied to clipboard", "结果已复制到剪贴板"))
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.86)))
                    .overlay(Capsule().stroke(DuoPalette.strokeBright, lineWidth: 1))
                    .padding(.bottom, 22)
                }
            }
        }
        .navigationTitle(hsbL("AI Intelligence", "端侧大模型实验室"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refreshStatusAndMetadata()
        }
    }
    
    // MARK: - 顶部引擎激活条
    private var statusBannerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DuoPalette.readyGreen.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DuoPalette.readyGreen)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("当前加载 AI 引擎")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(DuoPalette.textSecondary)
                Text(viewModel.engineTitle.isEmpty ? "Apple 内置离线 AI" : viewModel.engineTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DuoPalette.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onOpenModelCenter) {
                Text("切换模型")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(DuoPalette.brandPurple.opacity(0.85)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    // MARK: - 场景切换 + 语言选项
    private var scenarioAndLanguageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("测试场景", selection: $viewModel.scenario) {
                Text("同声传译").tag(HSBLLMTestScenarioType.translation)
                Text("电视控屏").tag(HSBLLMTestScenarioType.webControl)
                Text("智能管家").tag(HSBLLMTestScenarioType.smartButler)
            }
            .pickerStyle(.segmented)
            
            if viewModel.scenario == .translation {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(viewModel.supportedLanguages(isSource: true), id: \.self) { lang in
                            Button(lang) {
                                viewModel.selectLanguage(displayName: lang, isSource: true)
                            }
                        }
                    } label: {
                        languageChip(
                            prefix: "源",
                            value: viewModel.languageDisplayName(forKey: viewModel.sourceLanguageKey)
                        )
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DuoPalette.textMuted)
                    
                    Menu {
                        ForEach(viewModel.supportedLanguages(isSource: false), id: \.self) { lang in
                            Button(lang) {
                                viewModel.selectLanguage(displayName: lang, isSource: false)
                            }
                        }
                    } label: {
                        languageChip(
                            prefix: "译",
                            value: viewModel.languageDisplayName(forKey: viewModel.targetLanguageKey)
                        )
                    }
                }
            }
        }
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    private func languageChip(prefix: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(prefix)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(DuoPalette.brandBlue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6).fill(DuoPalette.brandBlue.opacity(0.16)))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DuoPalette.textPrimary)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10))
                .foregroundColor(DuoPalette.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DuoPalette.cardElevated))
    }
    
    // MARK: - 快捷标签 + 输入面板
    private var inputConsoleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.quickTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.quickTags.enumerated()), id: \.offset) { idx, tag in
                            Button {
                                viewModel.applyQuickTag(at: idx)
                            } label: {
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DuoPalette.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(DuoPalette.cardElevated))
                                    .overlay(Capsule().stroke(DuoPalette.stroke, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.inputText)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 14.5))
                    .foregroundColor(DuoPalette.textPrimary)
                    .frame(minHeight: 110, maxHeight: 160)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DuoPalette.cardElevated))
                
                if viewModel.inputText.isEmpty {
                    Text(viewModel.inputPlaceholder.isEmpty ? "请输入指令或待翻译内容..." : viewModel.inputPlaceholder)
                        .font(.system(size: 14))
                        .foregroundColor(DuoPalette.textMuted)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            
            HStack {
                Button {
                    viewModel.inputText = ""
                    viewModel.outputText = ""
                } label: {
                    Label("清空", systemImage: "xmark.circle")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(DuoPalette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    viewModel.sendOrStop()
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(.white)
                            Text("停止推理")
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("立即发送")
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(viewModel.isGenerating ? DuoPalette.accentRed : DuoPalette.brandBlue)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    // MARK: - 结果面板
    private var resultOutputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("端侧模型推理输出", systemImage: "text.bubble.fill")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(DuoPalette.readyGreen)
                Spacer()
                if !viewModel.outputText.isEmpty {
                    Button {
                        UIPasteboard.general.string = viewModel.outputText
                        withAnimation(.easeInOut(duration: 0.2)) {
                            copiedToastVisible = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                copiedToastVisible = false
                            }
                        }
                    } label: {
                        Label(hsbL("Copy Result", "复制结果"), systemImage: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DuoPalette.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(DuoPalette.cardElevated))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            ScrollView {
                if viewModel.outputText.isEmpty {
                    Text(
                        viewModel.isGenerating
                            ? "模型正在全速思考与逐字生成..."
                            : "点击“立即发送”或快捷词，即可体验端侧离线大模型即时反馈。"
                    )
                    .font(.system(size: 13.5))
                    .foregroundColor(DuoPalette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                } else {
                    Text(viewModel.outputText)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(DuoPalette.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minHeight: 160, maxHeight: 340)
            
            Text("全部端侧大模型推理或苹果本地翻译均直接在您的设备芯片上离线完成，绝对不上传用户对话历史。")
                .font(.system(size: 11))
                .foregroundColor(DuoPalette.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
}

#if DEBUG
#Preview("端侧大模型实验室 · 折叠窄屏") {
    DuoPreviewContainer("端侧大模型实验室", expandedDuo: false) {
        ModernLLMTestView(isPreviewMock: true) {}
    }
}

#Preview("端侧大模型实验室 · iPhone Duo 双栏展开") {
    DuoPreviewContainer("端侧大模型实验室", expandedDuo: true) {
        ModernLLMTestView(isPreviewMock: true) {}
    }
}
#endif
