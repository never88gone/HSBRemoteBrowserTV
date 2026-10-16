import Foundation

/// OPACKMessageBuilder
/// 专职负责 Apple TV Companion 协议的控制消息、HID 指令、手势与会话初始化 OPACK 封包构建
public enum OPACKMessageBuilder {

    private static func encodeUInt32(_ value: UInt32, into out: inout Data) {
        out.append(0x32)
        out.append(UInt8( value        & 0xFF))
        out.append(UInt8((value >> 8)  & 0xFF))
        out.append(UInt8((value >> 16) & 0xFF))
        out.append(UInt8((value >> 24) & 0xFF))
    }

    /// Encode a `_heartbeat` response (type=3) when the ATV initiates the heartbeat.
    public static func encodeHeartbeatResponse(txn: UInt32) -> Data {
        var out = Data()
        out.append(0xE3)              // dict, 3 entries
        OPACK.encodeStringDirect("_i", into: &out)
        OPACK.encodeStringDirect("_heartbeat", into: &out)
        OPACK.encodeStringDirect("_t", into: &out)
        out.append(0x08 + 3)          // small int: 3 (response)
        OPACK.encodeStringDirect("_x", into: &out)
        encodeUInt32(txn, into: &out)
        return out
    }

    /// Encode a `_pong` response to an ATV `_ping` request.
    /// _t: 3 = response (ATV sends _ping as _t: 2 request, expects _t: 3 response).
    public static func encodePong(txn: UInt32) -> Data {
        var out = Data()
        out.append(0xE3)              // dict, 3 entries
        OPACK.encodeStringDirect("_i", into: &out)
        OPACK.encodeStringDirect("_pong", into: &out)
        OPACK.encodeStringDirect("_t", into: &out)
        out.append(0x08 + 3)          // small int: 3 (response)
        OPACK.encodeStringDirect("_x", into: &out)
        encodeUInt32(txn, into: &out)
        return out
    }

    /// Encode `_systemInfo` request — tells the ATV who we are.
    public static func encodeSystemInfo(clientID: String, name: String, txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "_systemInfo",
            "_t": 2,
            "_x": txn,
            "_c": [
                "_bf":   0,
                "_cf":   512,
                "_clFl": 128,
                "_i":    clientID,
                "_idsID": Data(clientID.utf8),
                "_pubID": clientID,
                "_sf":   256,
                "_sv":   "170.18",
                "model": "MacBookPro",
                "name":  name,
            ] as [String: Any],
        ] as [String: Any])
    }

    /// Encode `_touchStart` request — part of the Companion session handshake.
    public static func encodeTouchStart(txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "_touchStart",
            "_t": 2,
            "_x": txn,
            "_c": [
                "_height": 1000,
                "_tFl":    0,
                "_width":  1000,
            ] as [String: Any],
        ] as [String: Any])
    }

    /// Encode a `_hidT` touch event — one frame in a swipe gesture sequence.
    public static func encodeTouchEvent(x: Double, y: Double, phase: Int,
                                        txn: UInt32, nanoseconds: UInt64) -> Data {
        OPACK.pack([
            "_i": "_hidT",
            "_t": 1,
            "_x": txn,
            "_c": [
                "_cx":  Int(x),
                "_cy":  Int(y),
                "_tPh": phase,
                "_tFg": 1,
                "_ns":  nanoseconds,
            ] as [String: Any],
        ] as [String: Any])
    }

    /// Encode a `_touchStop` frame — closes the touch session.
    public static func encodeTouchStop(txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "_touchStop",
            "_t": 2,
            "_x": txn,
            "_c": ["_i": 1] as [String: Any],
        ] as [String: Any])
    }

    /// Encode a HID button command (`_hidC`).
    public static func encodeHIDCommand(keycode: UInt8, state: Int, txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "_hidC", "_t": 2, "_x": txn,
            "_c": ["_hBtS": state, "_hidC": Int(keycode)] as [String: Any],
        ] as [String: Any])
    }

    /// Encode `_tiStart` (text input start) request.
    public static func encodeTextInputStart(txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "_tiStart",
            "_t": 2,
            "_x": txn,
            "_c": [String: Any](),
        ] as [String: Any])
    }

    /// Encode `_tiStop` — tears down the active text input session.
    public static func encodeTextInputStop(txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "_tiStop",
            "_t": 2,
            "_x": txn,
            "_c": [String: Any](),
        ] as [String: Any])
    }

    /// Encode `_tiC` — fire-and-forget event (_t:1) that sends text to the ATV.
    public static func encodeTextInputCommand(tiD: Data, txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "_tiC",
            "_t": 1,
            "_x": txn,
            "_c": [
                "_tiV": 1,
                "_tiD": tiD,
            ] as [String: Any],
        ] as [String: Any])
    }

    /// Encode a `FetchAttentionState` Request.
    public static func encodeFetchAttentionState(txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "FetchAttentionState",
            "_t": 2,
            "_x": txn,
            "_c": [String: Any](),
        ] as [String: Any])
    }

    /// Fetch list of launchable apps from the ATV.
    public static func encodeFetchLaunchableApplicationsEvent(txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "FetchLaunchableApplicationsEvent",
            "_t": 2,
            "_x": txn,
            "_c": [String: Any](),
        ] as [String: Any])
    }

    /// Launch an app by bundle ID.
    public static func encodeLaunchApp(bundleID: String, txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "_launchApp",
            "_t": 2,
            "_x": txn,
            "_c": ["_bundleID": bundleID],
        ] as [String: Any])
    }

    /// Encode `_sessionStart` request.
    public static func encodeSessionStart(txn: UInt32, localSID: UInt32) -> Data {
        OPACK.pack([
            "_i": "_sessionStart",
            "_t": 2,
            "_x": txn,
            "_c": [
                "_srvT": "com.apple.tvremoteservices",
                "_sid":  localSID,
            ] as [String: Any],
        ] as [String: Any])
    }

    /// Encode `TVRCSessionStart` — registers a TV Remote Client session with tvremoted.
    public static func encodeTVRCSessionStart(txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "TVRCSessionStart",
            "_t": 2,
            "_x": txn,
            "_c": ["ProtocolVersionKey": "1.2"] as [String: Any],
        ] as [String: Any])
    }

    /// Encode `_interest` event subscription.
    public static func encodeInterest(events: [String], txn: UInt32) -> Data {
        OPACK.pack([
            "_i": "_interest",
            "_t": 1,
            "_x": txn,
            "_c": [
                "_regEvents": events as [Any],
            ] as [String: Any],
        ] as [String: Any])
    }
}
