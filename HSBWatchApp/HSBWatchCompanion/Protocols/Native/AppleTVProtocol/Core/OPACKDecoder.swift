import Foundation

/// OPACKDecoder
/// 专职负责 Apple TV 协议二进制 OPACK 数据的解码与字段提取
public enum OPACKDecoder {

    private static let maxDictEntries = 10_000

    /// Decode a top-level OPACK dict into [String: Any].
    public static func decodeDict(_ data: Data) -> [String: Any]? {
        var cursor = data.startIndex
        guard cursor < data.endIndex else { return nil }
        let tag = data[cursor]
        guard tag >= 0xE0, tag <= 0xEF else { return nil }
        data.formIndex(after: &cursor)
        let count = Int(tag - 0xE0)
        let isOpen = count == 0xF  // 0xEF = open-ended, terminated by 0x03
        var result = [String: Any]()
        var iterations = 0
        while true {
            if isOpen {
                // Check for terminator 0x03
                if cursor < data.endIndex, data[cursor] == 0x03 { break }
            } else {
                if iterations >= count { break }
            }
            if iterations >= maxDictEntries {
                Log.opack.fail("OPACK decodeDict: bailing at \(maxDictEntries) entries (open-ended attacker amplification?)")
                break
            }
            guard let key = OPACK.readStringDirect(data, cursor: &cursor) else { break }
            if let s = peekString(data, cursor: &cursor) {
                result[key] = s
            } else if let f = peekDouble(data, cursor: &cursor) {
                result[key] = f
            } else if let i = peekInt(data, cursor: &cursor) {
                result[key] = i
            } else if let b = peekBytes(data, cursor: &cursor) {
                result[key] = b
            } else if let d = peekNestedDict(data, cursor: &cursor) {
                result[key] = d
            } else {
                OPACK.skipValueDirect(data, cursor: &cursor)
            }
            iterations += 1
        }
        return result
    }

    /// Fast shallow decode: reads only scalar top-level values (string, int, bool, bytes).
    public static func decodeDictShallow(_ data: Data) -> [String: Any]? {
        var cursor = data.startIndex
        guard cursor < data.endIndex else { return nil }
        let tag = data[cursor]
        guard tag >= 0xE0, tag <= 0xEF else { return nil }
        data.formIndex(after: &cursor)
        let count = Int(tag - 0xE0)
        let isOpen = count == 0xF
        var result = [String: Any]()
        var iterations = 0
        while true {
            if isOpen {
                if cursor >= data.endIndex || data[cursor] == 0x03 { break }
            } else {
                if iterations >= count { break }
            }
            if iterations >= maxDictEntries {
                Log.opack.fail("OPACK decodeDictShallow: bailing at \(maxDictEntries) entries (open-ended attacker amplification?)")
                break
            }
            let before = cursor
            guard let key = OPACK.readStringDirect(data, cursor: &cursor) else { break }
            let beforeValue = cursor
            if let s = peekString(data, cursor: &cursor) {
                result[key] = s
            } else if let i = peekInt(data, cursor: &cursor) {
                result[key] = i
            } else if let f = peekDouble(data, cursor: &cursor) {
                result[key] = f
            } else if let b = peekBytes(data, cursor: &cursor) {
                result[key] = b
            } else {
                OPACK.skipValueDirect(data, cursor: &cursor)  // skip nested dicts/arrays — shallow
            }
            if cursor == beforeValue { break }  // value didn't advance — corrupt/unknown tag
            if cursor == before { break }  // guard against full no-progress
            iterations += 1
        }
        return result
    }

    private static func peekString(_ data: Data, cursor: inout Data.Index) -> String? {
        let saved = cursor
        if let s = OPACK.readStringDirect(data, cursor: &cursor) { return s }
        cursor = saved; return nil
    }

    private static func peekInt(_ data: Data, cursor: inout Data.Index) -> Int? {
        guard cursor < data.endIndex else { return nil }
        let tag = data[cursor]
        switch tag {
        case 0x08...0x2F:
            data.formIndex(after: &cursor)
            return Int(tag) - 0x08
        case 0x30:
            guard let u = readLittleEndianUInt(data, cursor: cursor, byteCount: 1) else { return nil }
            data.formIndex(&cursor, offsetBy: 2)
            return Int(u)
        case 0x31:
            guard let u = readLittleEndianUInt(data, cursor: cursor, byteCount: 2) else { return nil }
            data.formIndex(&cursor, offsetBy: 3)
            return Int(u)
        case 0x32:
            guard let u = readLittleEndianUInt(data, cursor: cursor, byteCount: 4) else { return nil }
            data.formIndex(&cursor, offsetBy: 5)
            return Int(u)
        case 0x33:
            guard let u = readLittleEndianUInt(data, cursor: cursor, byteCount: 8) else { return nil }
            data.formIndex(&cursor, offsetBy: 9)
            return Int(bitPattern: UInt(u))
        case 0x35:
            guard let u = readLittleEndianUInt(data, cursor: cursor, byteCount: 4) else { return nil }
            data.formIndex(&cursor, offsetBy: 5)
            return Int(Int32(bitPattern: UInt32(u)))
        case 0x36:
            guard let u = readLittleEndianUInt(data, cursor: cursor, byteCount: 8) else { return nil }
            data.formIndex(&cursor, offsetBy: 9)
            return Int(Int64(bitPattern: u))
        default: return nil
        }
    }

    private static func readLittleEndianUInt(_ data: Data,
                                             cursor: Data.Index,
                                             byteCount: Int) -> UInt64? {
        guard data.distance(from: cursor, to: data.endIndex) >= 1 + byteCount else { return nil }
        var v: UInt64 = 0
        for offset in stride(from: byteCount, through: 1, by: -1) {
            v = (v << 8) | UInt64(data[data.index(cursor, offsetBy: offset)])
        }
        return v
    }

    private static func peekDouble(_ data: Data, cursor: inout Data.Index) -> Double? {
        let saved = cursor
        guard cursor < data.endIndex else { return nil }
        let tag = data[cursor]
        data.formIndex(after: &cursor)
        switch tag {
        case 0x06:
            guard data.distance(from: cursor, to: data.endIndex) >= 4 else { cursor = saved; return nil }
            var bits: UInt32 = 0
            for i in 0..<4 { bits = (bits << 8) | UInt32(data[data.index(cursor, offsetBy: i)]) }
            data.formIndex(&cursor, offsetBy: 4)
            return Double(Float(bitPattern: bits))
        case 0x07:
            guard data.distance(from: cursor, to: data.endIndex) >= 8 else { cursor = saved; return nil }
            var bits: UInt64 = 0
            for i in 0..<8 { bits = (bits << 8) | UInt64(data[data.index(cursor, offsetBy: i)]) }
            data.formIndex(&cursor, offsetBy: 8)
            return Double(bitPattern: bits)
        default:
            cursor = saved; return nil
        }
    }

    private static func peekBytes(_ data: Data, cursor: inout Data.Index) -> Data? {
        let saved = cursor
        if let b = OPACK.readBytesDirect(data, cursor: &cursor) { return b }
        cursor = saved; return nil
    }

    private static func peekNestedDict(_ data: Data, cursor: inout Data.Index) -> [String: Any]? {
        let saved = cursor
        guard cursor < data.endIndex else { return nil }
        let tag = data[cursor]
        guard tag >= 0xE0, tag <= 0xEF else { return nil }
        if let d = decodeDict(data[cursor...]) {
            data.formIndex(after: &cursor)
            let count = Int(tag - 0xE0)
            let isOpen = count == 0xF
            var iterations = 0
            while true {
                if isOpen {
                    if cursor < data.endIndex, data[cursor] == 0x03 {
                        data.formIndex(after: &cursor); break
                    }
                } else {
                    if iterations >= count { break }
                }
                OPACK.skipValueDirect(data, cursor: &cursor)
                OPACK.skipValueDirect(data, cursor: &cursor)
                iterations += 1
            }
            return d
        }
        cursor = saved; return nil
    }
}
