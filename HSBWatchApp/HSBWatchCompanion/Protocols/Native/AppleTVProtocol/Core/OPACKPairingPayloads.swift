import Foundation

/// OPACKPairingPayloads
/// 专职负责 Apple TV 配对与握手过程中 TLV8 载荷的 OPACK 封装与提取
public enum OPACKPairingPayloads {

    /// Encode `{"name": displayName}` for the Companion-specific TLV8 tag=0x11 in pair-setup M5.
    public static func encodeDeviceName(_ displayName: String) -> Data {
        var out = Data()
        out.append(0xE1)   // dict, 1 entry
        OPACK.encodeStringDirect("name", into: &out)
        OPACK.encodeStringDirect(displayName, into: &out)
        return out
    }

    /// Wrap raw TLV8 bytes in `{"_pd": data}` for pvNext frames.
    public static func wrapPairingData(_ tlvData: Data) -> Data {
        var out = Data()
        out.append(0xE1)                    // dict, 1 entry
        OPACK.encodeStringDirect("_pd", into: &out)
        OPACK.encodeBytesDirect(tlvData, into: &out)
        return out
    }

    /// Wrap raw TLV8 bytes for psStart — `{"_pd": data, "_pwTy": 1}`.
    /// `_pwTy: 1` triggers PIN display on the Apple TV.
    public static func wrapPsStartData(_ tlvData: Data) -> Data {
        var out = Data()
        out.append(0xE2)                    // dict, 2 entries
        OPACK.encodeStringDirect("_pd", into: &out)
        OPACK.encodeBytesDirect(tlvData, into: &out)
        OPACK.encodeStringDirect("_pwTy", into: &out)
        out.append(0x09)                    // small int: 1
        return out
    }

    /// Wrap raw TLV8 bytes for psNext (M3/M5) — `{"_pd": data, "_pwTy": 1}`.
    public static func wrapPsNextData(_ tlvData: Data) -> Data {
        var out = Data()
        out.append(0xE2)                    // dict, 2 entries
        OPACK.encodeStringDirect("_pd", into: &out)
        OPACK.encodeBytesDirect(tlvData, into: &out)
        OPACK.encodeStringDirect("_pwTy", into: &out)
        out.append(0x09)                    // small int: 1
        return out
    }

    /// Wrap raw TLV8 bytes for pvStart — `{"_pd": data, "_auTy": 4}`.
    public static func wrapPvStartData(_ tlvData: Data) -> Data {
        var out = Data()
        out.append(0xE2)                    // dict, 2 entries
        OPACK.encodeStringDirect("_pd", into: &out)
        OPACK.encodeBytesDirect(tlvData, into: &out)
        OPACK.encodeStringDirect("_auTy", into: &out)
        out.append(0x0C)                    // small int: 4 (0x08 + 4)
        return out
    }

    /// Extract the `_pd` bytes value from an OPACK dict, or nil if not found.
    public static func extractPairingData(from opack: Data) -> Data? {
        var cursor = opack.startIndex
        guard let count = OPACK.readDictHeaderDirect(opack, cursor: &cursor) else { return nil }
        for _ in 0..<count {
            guard let key = OPACK.readStringDirect(opack, cursor: &cursor) else { break }
            if key == "_pd" {
                return OPACK.readBytesDirect(opack, cursor: &cursor)
            }
            OPACK.skipValueDirect(opack, cursor: &cursor)
        }
        return nil
    }
}
