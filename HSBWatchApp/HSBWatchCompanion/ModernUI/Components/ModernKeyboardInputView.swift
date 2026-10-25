//
//  ModernKeyboardInputView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

public struct ModernKeyboardInputView: View {
    @Binding public var isPresented: Bool
    public var onTextChange: ((String, Bool) -> Void)?
    public var onSubmit: (() -> Void)?
    public var onSubmitText: ((String) -> Void)?
    public var onBackspace: (() -> Void)?
    
    @State private var inputText: String = ""
    @State private var shouldFocusField: Bool = false
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    public init(
        isPresented: Binding<Bool>,
        onTextChange: ((String, Bool) -> Void)? = nil,
        onSubmit: (() -> Void)? = nil,
        onSubmitText: ((String) -> Void)? = nil,
        onBackspace: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.onTextChange = onTextChange
        self.onSubmit = onSubmit
        self.onSubmitText = onSubmitText
        self.onBackspace = onBackspace
    }
    
    private func handleCommit() {
        let textToCommit = inputText
        shouldFocusField = false
        if !textToCommit.isEmpty {
            onSubmitText?(textToCommit)
        }
        onSubmit?()
        inputText = ""
        isPresented = false
    }
    
    private func dispatchRemoteBackspace() {
        lightHaptic.impactOccurred()
        if let onBackspace = onBackspace {
            onBackspace()
        } else if DualModeRemoteCoordinator.shared.isCurrentTargetMac {
            MacMediaCommandDispatcher.dispatchCommand("backspace")
        } else {
            DualModeRemoteCoordinator.shared.sendKeyCommand(key: .backspace)
        }
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("输入文本同步至 Mac / 大屏")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                
                // 快捷退格删除按钮 (随时点击即可删除 Mac / 大屏当前焦点处的字符)
                Button(action: {
                    if !inputText.isEmpty {
                        inputText.removeLast()
                        onTextChange?(inputText, false)
                    }
                    dispatchRemoteBackspace()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("退格")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.tertiarySystemFill))
                    )
                }
                .accessibilityIdentifier("remote_backspace_button")
                .accessibilityLabel("退格删除")
                
                Button(action: {
                    shouldFocusField = false
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("关闭输入")
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 8) {
                BackspaceAwareTextField(
                    text: $inputText,
                    isFirstResponder: $shouldFocusField,
                    placeholder: "在此键入内容发送至当前焦点...",
                    onTextChange: { newValue, isMarked in
                        onTextChange?(newValue, isMarked)
                    },
                    onCommit: {
                        handleCommit()
                    },
                    onDeleteWhenEmpty: {
                        dispatchRemoteBackspace()
                    }
                )
                .frame(height: 36)
                
                if !inputText.isEmpty {
                    Button(action: {
                        inputText = ""
                        onTextChange?("", false)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    .accessibilityLabel("清空输入")
                }
                
                Button(action: {
                    handleCommit()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
                .accessibilityIdentifier("send_text_button")
                .accessibilityLabel("发送文本")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                shouldFocusField = true
            }
        }
    }
}

// MARK: - 支持监听空输入框软键盘退格键 (deleteBackward) 的原生 UITextField 包装
private final class BackspaceDetectingUITextField: UITextField {
    var onDeleteWhenEmpty: (() -> Void)?
    
    override func deleteBackward() {
        let wasEmpty = (self.text ?? "").isEmpty
        super.deleteBackward()
        if wasEmpty {
            onDeleteWhenEmpty?()
        }
    }
}

private struct BackspaceAwareTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    var placeholder: String
    var onTextChange: (String, Bool) -> Void
    var onCommit: () -> Void
    var onDeleteWhenEmpty: () -> Void
    
    func makeUIView(context: Context) -> BackspaceDetectingUITextField {
        let tf = BackspaceDetectingUITextField()
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 15)
        tf.returnKeyType = .send
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.accessibilityIdentifier = "remote_text_field"
        tf.delegate = context.coordinator
        tf.onDeleteWhenEmpty = {
            context.coordinator.parent.onDeleteWhenEmpty()
        }
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return tf
    }
    
    func updateUIView(_ uiView: BackspaceDetectingUITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text && uiView.markedTextRange == nil {
            uiView.text = text
        }
        if isFirstResponder && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if !isFirstResponder && uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.resignFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: BackspaceAwareTextField
        
        init(parent: BackspaceAwareTextField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            let newText = textField.text ?? ""
            let isMarked = (textField.markedTextRange != nil)
            parent.text = newText
            parent.onTextChange(newText, isMarked)
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit()
            return true
        }
    }
}
