import Foundation
// import AppleTVLogging

/// Minimal OPACK encoder/decoder for the Companion protocol pairing frames.
///
/// Full OPACK spec (Apple internal binary serialization). We only implement
/// the subset needed: dicts with string keys and bytes/string/int values.
///
/// Wire types used here:
///   0x01         true
///   0x02         false
///   0x04         null
///   0x08–0x2F    small integers (value = byte - 0x08)
///   0x30         uint8  (1 byte follows)
///   0x31         uint16 (2 bytes, little-endian)
///   0x32         uint32 (4 bytes, little-endian)
///   0x33         uint64 (8 bytes)
///   0x40–0x5F    string, length = byte - 0x40  (0–31 UTF-8 bytes)
///   0x60         string, 1-byte length follows
///   0x70–0x8F    bytes,  length = byte - 0x70  (0–31 bytes)
///   0x90         bytes,  1-byte length follows
///   0x91         bytes,  1-byte length follows  (ATV uses this; treated same as 0x90)
///   0x92         bytes,  2-byte little-endian length follows
///   0x93         bytes,  4-byte little-endian length follows
///   0xD0–0xDF    array,  count = byte - 0xD0   (0–15 items)
///   0xE0–0xEF    dict,   count = byte - 0xE0   (0–15 key-value pairs)
public enum OPACK {

    private static let maxDictEntries = 10_000

    private static func encodeUInt32(_ value: UInt32, into out: inout Data) {
        out.append(0x32)
        out.append(UInt8( value        & 0xFF))
        out.append(UInt8((value >> 8)  & 0xFF))
        out.append(UInt8((value >> 16) & 0xFF))
        out.append(UInt8((value >> 24) & 0xFF))
    }

    // MARK: - General OPACK encoder

    /// Encode any Swift value into OPACK bytes.
    /// Supports: String, Int, UInt32, Bool, Data, [String: Any], [Any].
    public static func pack(_ value: Any) -> Data {
        var out = Data()
        packValue(value, into: &out)
        return out
    }

    private static func packValue(_ value: Any, into out: inout Data) {
        switch value {
        case is NSNull:
            out.append(0x04)  // OPACK null tag (pyatv support/opack.py)
        case let s as String:
            encodeString(s, into: &out)
        case let i as Int:
            encodeInt(i, into: &out)
        case let u as UInt32:
            encodeInt(Int(u), into: &out)
        case let u as UInt64:
            if u <= UInt64(Int64.max) {
                encodeInt(Int(u), into: &out)
            } else {
                out.append(0x33)
                appendLittleEndian(u, byteCount: 8, into: &out)
            }
        case let d as Data:
            encodeBytes(d, into: &out)
        case let b as Bool:
            out.append(b ? 0x01 : 0x02)
        case let dict as [String: Any]:
            // OPACK dicts with 0–15 entries are encoded inline with tag 0xE0+count.
            // We don't currently emit a variable-length form, so larger dicts are
            // a programming error (silent truncation was the old behavior — now fails loud).
            precondition(dict.count <= 15, "OPACK dict with > 15 entries is not supported")
            out.append(UInt8(0xE0 + dict.count))
            // Sort keys lexicographically so the wire output is deterministic —
            // Swift Dictionary iteration order is otherwise unspecified.
            for k in dict.keys.sorted() {
                encodeString(k, into: &out)
                packValue(dict[k]!, into: &out)
            }
        case let arr as [Any]:
            precondition(arr.count <= 15, "OPACK array with > 15 entries is not supported")
            out.append(UInt8(0xD0 + arr.count))
            for item in arr { packValue(item, into: &out) }
        default:
            assertionFailure("OPACK.packValue: unsupported type \(type(of: value))")
            out.append(0x04)  // null — safe fallback in release builds
        }
    }

    /// Encode a Swift Int using the narrowest OPACK tag that exactly represents it.
    ///
    ///   0x08..0x2F   small int 0–39
    ///   0x30         uint8   (40..255)
    ///   0x31         uint16  (256..65535, little-endian)
    ///   0x32         uint32  (65536..UInt32.max, little-endian)
    ///   0x33         uint64  (values above UInt32.max, little-endian)
    ///   0x36         int64   (any negative, two's complement little-endian)
    ///
    /// Pre-fix behavior clamped to Int32 range via UInt32(bitPattern: Int32(clamping:)),
    /// which silently corrupted negatives (−1 → 0xFFFFFFFF = +4294967295) and large
    /// positives (Int64 overflow clamped to Int32.max).
    private static func encodeInt(_ i: Int, into out: inout Data) {
        if i >= 0 {
            if i <= 0x27 {
                out.append(UInt8(0x08 + i))
            } else if i <= 0xFF {
                out.append(0x30)
                out.append(UInt8(i))
            } else if i <= 0xFFFF {
                out.append(0x31)
                appendLittleEndian(UInt64(i), byteCount: 2, into: &out)
            } else if i <= 0xFFFF_FFFF {
                out.append(0x32)
                appendLittleEndian(UInt64(i), byteCount: 4, into: &out)
            } else {
                out.append(0x33)
                appendLittleEndian(UInt64(i), byteCount: 8, into: &out)
            }
        } else {
            // Negative → signed 64-bit (0x36), two's complement big-endian.
            out.append(0x36)
            appendLittleEndian(UInt64(bitPattern: Int64(i)), byteCount: 8, into: &out)
        }
    }

    private static func appendLittleEndian(_ value: UInt64, byteCount: Int, into out: inout Data) {
        for offset in stride(from: 0, through: (byteCount - 1) * 8, by: 8) {
            out.append(UInt8((value >> offset) & 0xFF))
        }
    }

    // MARK: - Direct Encoding / Decoding Helpers

    public static func encodeStringDirect(_ s: String, into out: inout Data) {
        encodeString(s, into: &out)
    }
    public static func encodeBytesDirect(_ data: Data, into out: inout Data) {
        encodeBytes(data, into: &out)
    }
    public static func readDictHeaderDirect(_ data: Data, cursor: inout Data.Index) -> Int? {
        readDictHeader(data, cursor: &cursor)
    }
    public static func readStringDirect(_ data: Data, cursor: inout Data.Index) -> String? {
        readString(data, cursor: &cursor)
    }
    public static func readBytesDirect(_ data: Data, cursor: inout Data.Index) -> Data? {
        readBytes(data, cursor: &cursor)
    }
    public static func skipValueDirect(_ data: Data, cursor: inout Data.Index) {
        skipValue(data, cursor: &cursor)
    }

    // MARK: - Session message helpers

    @inline(__always) public static func encodeHeartbeatResponse(txn: UInt32) -> Data { OPACKMessageBuilder.encodeHeartbeatResponse(txn: txn) }
    @inline(__always) public static func encodePong(txn: UInt32) -> Data { OPACKMessageBuilder.encodePong(txn: txn) }
    @inline(__always) public static func encodeSystemInfo(clientID: String, name: String, txn: UInt32) -> Data { OPACKMessageBuilder.encodeSystemInfo(clientID: clientID, name: name, txn: txn) }
    @inline(__always) public static func encodeTouchStart(txn: UInt32) -> Data { OPACKMessageBuilder.encodeTouchStart(txn: txn) }
    @inline(__always) public static func encodeTouchEvent(x: Double, y: Double, phase: Int, txn: UInt32, nanoseconds: UInt64) -> Data { OPACKMessageBuilder.encodeTouchEvent(x: x, y: y, phase: phase, txn: txn, nanoseconds: nanoseconds) }
    @inline(__always) public static func encodeTouchStop(txn: UInt32) -> Data { OPACKMessageBuilder.encodeTouchStop(txn: txn) }
    @inline(__always) public static func encodeHIDCommand(keycode: UInt8, state: Int, txn: UInt32) -> Data { OPACKMessageBuilder.encodeHIDCommand(keycode: keycode, state: state, txn: txn) }
    @inline(__always) public static func encodeTextInputStart(txn: UInt32) -> Data { OPACKMessageBuilder.encodeTextInputStart(txn: txn) }
    @inline(__always) public static func encodeTextInputStop(txn: UInt32) -> Data { OPACKMessageBuilder.encodeTextInputStop(txn: txn) }
    @inline(__always) public static func encodeTextInputCommand(tiD: Data, txn: UInt32) -> Data { OPACKMessageBuilder.encodeTextInputCommand(tiD: tiD, txn: txn) }
    @inline(__always) public static func encodeFetchAttentionState(txn: UInt32) -> Data { OPACKMessageBuilder.encodeFetchAttentionState(txn: txn) }
    @inline(__always) public static func encodeFetchLaunchableApplicationsEvent(txn: UInt32) -> Data { OPACKMessageBuilder.encodeFetchLaunchableApplicationsEvent(txn: txn) }
    @inline(__always) public static func encodeLaunchApp(bundleID: String, txn: UInt32) -> Data { OPACKMessageBuilder.encodeLaunchApp(bundleID: bundleID, txn: txn) }
    @inline(__always) public static func encodeSessionStart(txn: UInt32, localSID: UInt32) -> Data { OPACKMessageBuilder.encodeSessionStart(txn: txn, localSID: localSID) }
    @inline(__always) public static func encodeTVRCSessionStart(txn: UInt32) -> Data { OPACKMessageBuilder.encodeTVRCSessionStart(txn: txn) }
    @inline(__always) public static func encodeInterest(events: [String], txn: UInt32) -> Data { OPACKMessageBuilder.encodeInterest(events: events, txn: txn) }

    // MARK: - Decoding

    /// Decode a top-level OPACK dict into [String: Any].
    @inline(__always) public static func decodeDict(_ data: Data) -> [String: Any]? {
        OPACKDecoder.decodeDict(data)
    }

    /// Fast shallow decode: reads only scalar top-level values (string, int, bool, bytes).
    @inline(__always) public static func decodeDictShallow(_ data: Data) -> [String: Any]? {
        OPACKDecoder.decodeDictShallow(data)
    }

    // MARK: - Pairing helpers

    @inline(__always) public static func encodeDeviceName(_ displayName: String) -> Data { OPACKPairingPayloads.encodeDeviceName(displayName) }
    @inline(__always) public static func wrapPairingData(_ tlvData: Data) -> Data { OPACKPairingPayloads.wrapPairingData(tlvData) }
    @inline(__always) public static func wrapPsStartData(_ tlvData: Data) -> Data { OPACKPairingPayloads.wrapPsStartData(tlvData) }
    @inline(__always) public static func wrapPsNextData(_ tlvData: Data) -> Data { OPACKPairingPayloads.wrapPsNextData(tlvData) }
    @inline(__always) public static func wrapPvStartData(_ tlvData: Data) -> Data { OPACKPairingPayloads.wrapPvStartData(tlvData) }
    @inline(__always) public static func extractPairingData(from opack: Data) -> Data? { OPACKPairingPayloads.extractPairingData(from: opack) }

    // MARK: - Encoding

    private static func encodeString(_ s: String, into out: inout Data) {
        let b = Data(s.utf8)
        if b.count <= 0x20 {
            out.append(UInt8(0x40 + b.count))
        } else if b.count <= 0xFF {
            out.append(0x61)
            out.append(UInt8(b.count & 0xFF))
        } else {
            out.append(0x62)
            out.append(UInt8(b.count & 0xFF))
            out.append(UInt8((b.count >> 8) & 0xFF))
        }
        out.append(contentsOf: b)
    }

    private static func encodeBytes(_ data: Data, into out: inout Data) {
        let n = data.count
        if n <= 0x1F {
            out.append(UInt8(0x70 + n))
        } else if n <= 0xFF {
            out.append(0x91)
            out.append(UInt8(n))
        } else if n <= 0xFFFF {
            out.append(0x92)
            out.append(UInt8(n & 0xFF))
            out.append(UInt8((n >> 8) & 0xFF))
        } else {
            precondition(n <= 0xFFFF_FFFF, "OPACK bytes > 4 GiB not supported")
            out.append(0x93)
            out.append(UInt8( n        & 0xFF))
            out.append(UInt8((n >>  8) & 0xFF))
            out.append(UInt8((n >> 16) & 0xFF))
            out.append(UInt8((n >> 24) & 0xFF))
        }
        out.append(contentsOf: data)
    }

    // MARK: - Decoding

    private static func readDictHeader(_ data: Data, cursor: inout Data.Index) -> Int? {
        guard cursor < data.endIndex else { return nil }
        let tag = data[cursor]
        guard tag >= 0xE0, tag <= 0xEF else { return nil }
        data.formIndex(after: &cursor)
        return Int(tag - 0xE0)
    }

    private static func readString(_ data: Data, cursor: inout Data.Index) -> String? {
        guard cursor < data.endIndex else { return nil }
        let tag = data[cursor]
        data.formIndex(after: &cursor)

        var length: Int
        switch tag {
        case 0x40...0x60:
            length = Int(tag - 0x40)
        case 0x61:
            guard cursor < data.endIndex else { return nil }
            length = Int(data[cursor]); data.formIndex(after: &cursor)
        case 0x62:
            guard data.distance(from: cursor, to: data.endIndex) >= 2 else { return nil }
            length = Int(data[cursor]) | (Int(data[data.index(cursor, offsetBy: 1)]) << 8)
            data.formIndex(&cursor, offsetBy: 2)
        default:
            return nil
        }
        guard data.index(cursor, offsetBy: length, limitedBy: data.endIndex) != nil,
              cursor.advanced(by: length) <= data.endIndex else { return nil }
        let end = data.index(cursor, offsetBy: length)
        let s = String(data: data[cursor..<end], encoding: .utf8)
        cursor = end
        return s
    }

    /// Sanity cap on attacker-controlled OPACK byte-length fields. The Companion
    /// link runs over a single TCP socket whose frame size is already bounded;
    /// nothing the ATV legitimately sends approaches this. A malformed or
    /// hostile length would otherwise drive an Int-sized allocation from the
    /// 4-byte 0x93 variant (up to 4 GiB).
    static let maxBytesLength = 1 << 20  // 1 MiB — orders of magnitude over the real payloads we see

    private static func readBytes(_ data: Data, cursor: inout Data.Index) -> Data? {
        guard cursor < data.endIndex else { return nil }
        let tag = data[cursor]
        data.formIndex(after: &cursor)

        var length: Int
        switch tag {
        case 0x70...0x8F:
            length = Int(tag - 0x70)
        case 0x90, 0x91:
            // 1-byte length: 0x90 and 0x91 both use a single length byte
            // (empirically confirmed: ATV sends 0x91 for medium-sized payloads)
            guard cursor < data.endIndex else { return nil }
            length = Int(data[cursor]); data.formIndex(after: &cursor)
        case 0x92:
            // 2-byte little-endian length (Companion OPACK convention)
            guard data.distance(from: cursor, to: data.endIndex) >= 2 else { return nil }
            length = Int(data[cursor]) | Int(data[data.index(cursor, offsetBy: 1)]) << 8
            data.formIndex(&cursor, offsetBy: 2)
        case 0x93:
            guard data.distance(from: cursor, to: data.endIndex) >= 4 else { return nil }
            length =  Int(data[cursor])
                   | (Int(data[data.index(cursor, offsetBy: 1)]) <<  8)
                   | (Int(data[data.index(cursor, offsetBy: 2)]) << 16)
                   | (Int(data[data.index(cursor, offsetBy: 3)]) << 24)
            data.formIndex(&cursor, offsetBy: 4)
        default:
            return nil
        }
        // Reject suspicious lengths before even checking buffer bounds — a
        // negative-after-sign-extension or implausibly-large value should
        // never produce a partial decode, just a clean nil.
        guard length >= 0, length <= Self.maxBytesLength else { return nil }
        guard data.distance(from: cursor, to: data.endIndex) >= length else { return nil }
        let end = data.index(cursor, offsetBy: length)
        let result = Data(data[cursor..<end])
        cursor = end
        return result
    }

    private static func skipValue(_ data: Data, cursor: inout Data.Index, depth: Int = 0) {
        guard cursor < data.endIndex else { return }
        guard depth < 32 else { cursor = data.endIndex; return }  // depth cap against stack overflow
        let tag = data[cursor]
        data.formIndex(after: &cursor)
        switch tag {
        case 0x01, 0x02, 0x04:   break                          // bool/null
        case 0x06:                advance(&cursor, by: 4, in: data) // float32
        case 0x07:                advance(&cursor, by: 8, in: data) // float64
        case 0x08...0x2F:         break                          // small int
        case 0x30:                advance(&cursor, by: 1, in: data)
        case 0x31:                advance(&cursor, by: 2, in: data)
        case 0x32, 0x35:          advance(&cursor, by: 4, in: data)
        case 0x33, 0x36:          advance(&cursor, by: 8, in: data)
        case 0x40...0x60:         advance(&cursor, by: Int(tag - 0x40), in: data)
        case 0x61:
            if cursor < data.endIndex { let n = Int(data[cursor]); data.formIndex(after: &cursor); advance(&cursor, by: n, in: data) }
        case 0x62:
            if data.distance(from: cursor, to: data.endIndex) >= 2 {
                let n = Int(data[cursor]) | Int(data[data.index(cursor, offsetBy: 1)]) << 8
                data.formIndex(&cursor, offsetBy: 2); advance(&cursor, by: n, in: data)
            }
        case 0x70...0x8F:         advance(&cursor, by: Int(tag - 0x70), in: data)
        case 0x90, 0x91:
            if cursor < data.endIndex { let n = Int(data[cursor]); data.formIndex(after: &cursor); advance(&cursor, by: n, in: data) }
        case 0x92:
            if data.distance(from: cursor, to: data.endIndex) >= 2 {
                let n = Int(data[cursor]) | Int(data[data.index(cursor, offsetBy: 1)]) << 8
                data.formIndex(&cursor, offsetBy: 2); advance(&cursor, by: n, in: data)
            }
        case 0x93:
            if data.distance(from: cursor, to: data.endIndex) >= 4 {
                let n =  Int(data[cursor])
                      | (Int(data[data.index(cursor, offsetBy: 1)]) <<  8)
                      | (Int(data[data.index(cursor, offsetBy: 2)]) << 16)
                      | (Int(data[data.index(cursor, offsetBy: 3)]) << 24)
                data.formIndex(&cursor, offsetBy: 4); advance(&cursor, by: n, in: data)
            }
        case 0xD0...0xDF:
            let count = Int(tag - 0xD0)
            for _ in 0..<count { skipValue(data, cursor: &cursor, depth: depth + 1) }
        case 0xE0...0xEF:
            let count = Int(tag - 0xE0)
            if count == 0xF {
                // open-ended dict: skip key-value pairs until 0x03 terminator
                while cursor < data.endIndex, data[cursor] != 0x03 {
                    let before = cursor
                    skipValue(data, cursor: &cursor, depth: depth + 1)  // key
                    skipValue(data, cursor: &cursor, depth: depth + 1)  // value
                    if cursor == before { break }     // guard: stuck cursor → corrupt data
                }
                if cursor < data.endIndex { data.formIndex(after: &cursor) }  // consume 0x03
            } else {
                for _ in 0..<(count * 2) { skipValue(data, cursor: &cursor, depth: depth + 1) }
            }
        default: break
        }
    }

    private static func advance(_ cursor: inout Data.Index, by n: Int, in data: Data) {
        let limit = data.endIndex
        _ = data.formIndex(&cursor, offsetBy: n, limitedBy: limit)
    }
}
