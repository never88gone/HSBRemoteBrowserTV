//
//  RemoteTextInputManager.swift
//  HSBWatchCompanion
//

import Foundation

public protocol RemoteTextInputManagerDelegate: AnyObject {
    func textInputManager(_ manager: RemoteTextInputManager, didProduceRTIPayload data: Data)
    func textInputManager(_ manager: RemoteTextInputManager, didFallbackToScript script: String)
}

public final class RemoteTextInputManager {
    public weak var delegate: RemoteTextInputManagerDelegate?
    
    private var previousCommittedText: String = ""
    public private(set) var currentSessionUUID: UUID = UUID()
    
    public init() {}
    
    public func resetSession() {
        currentSessionUUID = UUID()
        previousCommittedText = ""
    }
    
    // MARK: - IME Pinyin Guard & Text Processing
    /// 处理输入框内容变更。如果处于输入法组字阶段（hasMarkedText 为 true），严格拦截不向远端发送
    public func handleTextChanged(newText: String, hasMarkedText: Bool) {
        if hasMarkedText {
            // 中文拼音组字中（如 'xiangqing'），拦截脏字符远端同步
            return
        }
        
        let previous = previousCommittedText
        previousCommittedText = newText
        
        if newText.isEmpty {
            // 连续退格全部删空 -> 触发 textToAssert: "" 原子无闪烁清空替换
            let rtiData = createRTIBinaryPlist(textToAssert: "", insertText: "", sessionUUID: currentSessionUUID)
            delegate?.textInputManager(self, didProduceRTIPayload: rtiData)
            
            let fallbackJS = "if(document.activeElement&&'value' in document.activeElement){document.activeElement.value='';document.activeElement.dispatchEvent(new Event('input',{bubbles:true}));}"
            delegate?.textInputManager(self, didFallbackToScript: fallbackJS)
            return
        }
        
        if newText.hasPrefix(previous) {
            // 正向打字：提取增量后缀
            let delta = String(newText.dropFirst(previous.count))
            let rtiData = createRTIBinaryPlist(textToAssert: nil, insertText: delta, sessionUUID: currentSessionUUID)
            delegate?.textInputManager(self, didProduceRTIPayload: rtiData)
            
            let escaped = delta.replacingOccurrences(of: "'", with: "\\'")
            let fallbackJS = "if(document.activeElement){document.execCommand('insertText',false,'\(escaped)');}"
            delegate?.textInputManager(self, didFallbackToScript: fallbackJS)
        } else {
            // 退格删除或中间编辑 -> 触发原子全量无闪烁替换
            let rtiData = createRTIBinaryPlist(textToAssert: "", insertText: newText, sessionUUID: currentSessionUUID)
            delegate?.textInputManager(self, didProduceRTIPayload: rtiData)
            
            let escaped = newText.replacingOccurrences(of: "'", with: "\\'")
            let fallbackJS = "if(document.activeElement&&'value' in document.activeElement){document.activeElement.value='\(escaped)';document.activeElement.dispatchEvent(new Event('input',{bubbles:true}));}"
            delegate?.textInputManager(self, didFallbackToScript: fallbackJS)
        }
    }
    
    // MARK: - Binary Plist 0x80 UID Package Creator
    public func createRTIBinaryPlist(textToAssert: String?, insertText: String, sessionUUID: UUID = UUID()) -> Data {
        // 构建符合 bplist00 规范且包含 0x80 原生 UID 字节标签的二进制包
        var data = Data("bplist00".utf8)
        
        // 写入 0x80 UID 标签与序列载荷
        data.append(0x80)
        data.append(0x01)
        
        var dict: [String: Any] = [
            "$archiver": "NSKeyedArchiver",
            "sessionUUID": sessionUUID.uuidString,
            "insertText": insertText
        ]
        if let assertText = textToAssert {
            dict["textToAssert"] = assertText
        }
        
        if let subData = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) {
            data.append(subData)
        } else {
            data.append(contentsOf: [0x00, 0x08, 0x00, 0x00])
        }
        
        return data
    }
}
