//
//  ModernKeyboardInputView.swift
//  HSBWatchCompanion
//

import SwiftUI

public struct ModernKeyboardInputView: View {
    @Binding public var isPresented: Bool
    public var onTextChange: ((String, Bool) -> Void)?
    public var onSubmit: (() -> Void)?
    
    @State private var inputText: String = ""
    @FocusState private var isFieldFocused: Bool
    
    public init(
        isPresented: Binding<Bool>,
        onTextChange: ((String, Bool) -> Void)? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.onTextChange = onTextChange
        self.onSubmit = onSubmit
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("电视实时文本同步")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    isFieldFocused = false
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 8) {
                TextField("在此键入内容实时同步至大屏...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isFieldFocused)
                    .onChange(of: inputText) { newValue in
                        // 当输入变化时触发
                        onTextChange?(newValue, false)
                    }
                    .onSubmit {
                        onSubmit?()
                    }
                
                if !inputText.isEmpty {
                    Button(action: {
                        inputText = ""
                        onTextChange?("", false)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                }
                
                Button(action: {
                    onSubmit?()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
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
                isFieldFocused = true
            }
        }
    }
}
