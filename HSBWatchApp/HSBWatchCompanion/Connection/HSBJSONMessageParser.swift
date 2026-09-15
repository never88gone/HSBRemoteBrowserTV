//
//  HSBJSONMessageParser.swift
//  HSBWatchCompanion
//
//  Created for Milestone 1 Feature #2: Robust JSON Message Parser.
//

import Foundation

/// 独立健壮的 JSON 括号平衡拆包粘包解析器
/// 负责处理 TCP 字节流中的粘包、断包、字符串内嵌套括号转义与前导/包间乱码自愈
public final class HSBJSONMessageParser: @unchecked Sendable {
    
    // MARK: - Constants & Configuration
    
    /// 默认最大允许缓冲区容量 (2MB)，超过此限制且无法消费将触发熔断保护，防止内存泄露与 DoS 攻击
    public static let defaultMaxBufferSize: Int = 2 * 1024 * 1024
    
    /// 默认最大括号嵌套深度
    public static let defaultMaxDepth: Int = 128
    
    // ASCII 控制字符常量
    private static let byteBraceOpen: UInt8     = 0x7B // {
    private static let byteBraceClose: UInt8    = 0x7D // }
    private static let byteBracketOpen: UInt8   = 0x5B // [
    private static let byteBracketClose: UInt8  = 0x5D // ]
    private static let byteQuote: UInt8         = 0x22 // "
    private static let byteBackslash: UInt8     = 0x5C // \
    private static let byteSpace: UInt8         = 0x20 // Space
    private static let byteTab: UInt8           = 0x09 // \t
    private static let byteLineFeed: UInt8      = 0x0A // \n
    private static let byteCarriageReturn: UInt8 = 0x0D // \r
    
    // MARK: - Properties
    
    private var buffer: Data
    private let maxBufferSize: Int
    private let maxDepth: Int
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    /// 初始化解析器
    /// - Parameters:
    ///   - maxBufferSize: 缓冲区最大容量，默认 2MB
    ///   - maxDepth: 允许的 JSON 最大嵌套深度，默认 128 层
    public init(maxBufferSize: Int = defaultMaxBufferSize, maxDepth: Int = defaultMaxDepth) {
        self.buffer = Data()
        self.maxBufferSize = maxBufferSize
        self.maxDepth = maxDepth
    }
    
    // MARK: - Public Streaming API
    
    /// 追加新接收到的 TCP 数据切片，并提取出所有已就绪的完整 JSON 数据帧
    /// - Parameter data: 新到达的原始网络字节流
    /// - Returns: 提取出的独立完整 JSON 数据包数组
    @discardableResult
    public func append(data: Data) -> [Data] {
        guard !data.isEmpty else { return [] }
        
        lock.lock()
        defer { lock.unlock() }
        
        // 1. 追加数据到持久缓冲区
        buffer.append(data)
        
        // 2. 检查缓冲区熔断防护
        if buffer.count > maxBufferSize {
            let extraction = Self.extractMessages(from: buffer, maxDepth: maxDepth)
            if !extraction.messages.isEmpty {
                buffer = extraction.remaining
                return extraction.messages
            } else {
                // 严重异常：缓冲区超限且无法解析出任何有效 JSON，强行重置清空，防止 OOM
                buffer.removeAll(keepingCapacity: false)
                return []
            }
        }
        
        // 3. 执行纯函数式拆包提取
        let extraction = Self.extractMessages(from: buffer, maxDepth: maxDepth)
        buffer = extraction.remaining
        return extraction.messages
    }
    
    /// 重置内部缓冲区及状态
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll(keepingCapacity: false)
    }
    
    /// 当前残留在缓冲区中的未决字节数
    public var pendingByteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return buffer.count
    }
    
    // MARK: - Pure Functional Core
    
    /// 纯函数式拆包提取器：无内部可变状态与副作用
    /// - Parameters:
    ///   - buffer: 待解析的不可变 Data 数据流
    ///   - maxDepth: 允许的最大嵌套深度
    /// - Returns:
    ///   - messages: 成功提取出的完整 JSON 数据帧数组
    ///   - remaining: 未能闭合或等待后续数据的剩余数据帧
    public static func extractMessages(
        from buffer: Data,
        maxDepth: Int = defaultMaxDepth
    ) -> (messages: [Data], remaining: Data) {
        guard !buffer.isEmpty else {
            return ([], Data())
        }
        
        var messages: [Data] = []
        var startIndex: Int? = nil
        var consumedIndex: Int = 0
        
        // 括号匹配栈：存放期待的闭合符号 (0x7D '}' 或 0x5D ']')
        var bracketStack: [UInt8] = []
        bracketStack.reserveCapacity(16)
        
        var inString: Bool = false
        var escaped: Bool = false
        
        buffer.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            let length = rawBuffer.count
            guard length > 0, let baseAddress = rawBuffer.baseAddress else {
                return
            }
            let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
            
            var i = 0
            while i < length {
                let byte = bytes[i]
                
                // 1. 处于非包内状态 (寻找顶层起始括号)
                if startIndex == nil {
                    if byte == byteBraceOpen {
                        startIndex = i
                        bracketStack.removeAll(keepingCapacity: true)
                        bracketStack.append(byteBraceClose)
                        inString = false
                        escaped = false
                    } else if byte == byteBracketOpen {
                        startIndex = i
                        bracketStack.removeAll(keepingCapacity: true)
                        bracketStack.append(byteBracketClose)
                        inString = false
                        escaped = false
                    } else if byte == byteSpace || byte == byteLineFeed ||
                              byte == byteCarriageReturn || byte == byteTab {
                        // 丢弃空白符
                        consumedIndex = i + 1
                    } else {
                        // 丢弃非 JSON 前缀垃圾字节，防止死锁
                        consumedIndex = i + 1
                    }
                    i += 1
                    continue
                }
                
                // 2. 处于 JSON 字符串内部
                if inString {
                    if escaped {
                        escaped = false
                    } else if byte == byteBackslash {
                        escaped = true
                    } else if byte == byteQuote {
                        inString = false
                    }
                    i += 1
                    continue
                }
                
                // 3. 处于非字符串状态下的语法解析
                if byte == byteQuote {
                    inString = true
                } else if byte == byteBraceOpen {
                    guard bracketStack.count < maxDepth else {
                        // 超过最大嵌套深度，判定为畸形数据，丢弃当前包自愈
                        if let start = startIndex {
                            consumedIndex = start + 1
                            startIndex = nil
                            bracketStack.removeAll(keepingCapacity: true)
                            inString = false
                            escaped = false
                            i = start + 1
                            continue
                        }
                        startIndex = nil
                        consumedIndex = i + 1
                        i += 1
                        continue
                    }
                    bracketStack.append(byteBraceClose)
                } else if byte == byteBracketOpen {
                    guard bracketStack.count < maxDepth else {
                        if let start = startIndex {
                            consumedIndex = start + 1
                            startIndex = nil
                            bracketStack.removeAll(keepingCapacity: true)
                            inString = false
                            escaped = false
                            i = start + 1
                            continue
                        }
                        startIndex = nil
                        consumedIndex = i + 1
                        i += 1
                        continue
                    }
                    bracketStack.append(byteBracketClose)
                } else if byte == byteBraceClose || byte == byteBracketClose {
                    // 遇到闭合括号，校验是否与栈顶匹配
                    if let expectedClose = bracketStack.last, expectedClose == byte {
                        bracketStack.removeLast()
                        
                        // 若栈已清空，说明找到了顶层完整 JSON 闭合
                        if bracketStack.isEmpty, let start = startIndex {
                            let messageLength = i - start + 1
                            let messageSubdata = buffer.subdata(in: start..<(start + messageLength))
                            messages.append(messageSubdata)
                            
                            consumedIndex = i + 1
                            startIndex = nil
                        }
                    } else {
                        // 括号类型错配（例如 { [ } ]），判定当前包损坏，从 start + 1 回退自愈
                        if let start = startIndex {
                            consumedIndex = start + 1
                            startIndex = nil
                            bracketStack.removeAll(keepingCapacity: true)
                            inString = false
                            escaped = false
                            i = start + 1
                            continue
                        }
                    }
                }
                
                i += 1
            }
        }
        
        // 4. 切割并保留剩余数据
        let remaining: Data
        if consumedIndex >= buffer.count {
            remaining = Data()
        } else if consumedIndex > 0 {
            remaining = buffer.subdata(in: consumedIndex..<buffer.count)
        } else {
            // 未消费任何字节，整段保留
            remaining = buffer
        }
        
        return (messages, remaining)
    }
}
