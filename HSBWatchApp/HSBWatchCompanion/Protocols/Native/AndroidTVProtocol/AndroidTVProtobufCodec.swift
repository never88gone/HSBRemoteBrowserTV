//
//  AndroidTVProtobufCodec.swift
//  HSBWatchCompanion
//
//  纯原生实现 Google Android TV Remote Control Protocol v2 (Polo 配对协议 + RemoteMessage 控制协议)
//  的 Protocol Buffers Wire Format 编解码与 Base-128 Varint 分帧引擎。
//

import Foundation

// MARK: - Protobuf Wire Primitives

public enum ProtobufDecodeError: Error, Equatable {
    case malformedVarint
    case truncatedData
    case unsupportedWireType(UInt8)
    case messageTooLarge(Int)
}

public enum ProtobufWireType: UInt8 {
    case varint = 0
    case fixed64 = 1
    case lengthDelimited = 2
    case startGroup = 3
    case endGroup = 4
    case fixed32 = 5
}

public enum ProtobufCodec {
    public static func encodeVarint(_ value: UInt64) -> Data {
        var v = value
        var data = Data()
        while v >= 0x80 {
            data.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v))
        return data
    }
    
    public static func encodeSignedVarint32(_ value: Int32) -> Data {
        // 标准 Protobuf 负 int32 采用 10 字节补码 varint
        return encodeVarint(UInt64(bitPattern: Int64(value)))
    }
    
    /// 从缓冲区的头部尝试解码长度前缀帧：[Varint Length] + [Payload Bytes]
    /// 返回 nil 表示数据尚未收齐（半包），抛出异常表示流格式损坏。
    public static func popLengthPrefixedFrame(from buffer: inout Data, maxFrameBytes: Int = 4 * 1024 * 1024) throws -> Data? {
        guard !buffer.isEmpty else { return nil }
        var offset = buffer.startIndex
        var shift: UInt64 = 0
        var lengthValue: UInt64 = 0
        var varintComplete = false
        
        while offset < buffer.endIndex {
            let byte = buffer[offset]
            offset = buffer.index(after: offset)
            if shift >= 64 {
                throw ProtobufDecodeError.malformedVarint
            }
            lengthValue |= UInt64(byte & 0x7F) << shift
            if (byte & 0x80) == 0 {
                varintComplete = true
                break
            }
            shift += 7
        }
        
        if !varintComplete {
            return nil
        }
        
        guard lengthValue <= UInt64(maxFrameBytes) else {
            throw ProtobufDecodeError.messageTooLarge(Int(min(lengthValue, UInt64(Int.max))))
        }
        
        let headerBytes = buffer.distance(from: buffer.startIndex, to: offset)
        let frameLength = Int(lengthValue)
        guard buffer.count >= headerBytes + frameLength else {
            return nil
        }
        
        let payloadStart = buffer.index(buffer.startIndex, offsetBy: headerBytes)
        let payloadEnd = buffer.index(payloadStart, offsetBy: frameLength)
        let payload = Data(buffer[payloadStart..<payloadEnd])
        buffer.removeSubrange(buffer.startIndex..<payloadEnd)
        return payload
    }
    
    public static func wrapLengthPrefixed(_ payload: Data) -> Data {
        var out = encodeVarint(UInt64(payload.count))
        out.append(payload)
        return out
    }
}

public struct ProtobufWriter {
    public private(set) var data = Data()
    
    public init() {}
    
    public mutating func writeVarintField(_ fieldNumber: Int, value: UInt64) {
        let tag = UInt64((fieldNumber << 3) | Int(ProtobufWireType.varint.rawValue))
        data.append(ProtobufCodec.encodeVarint(tag))
        data.append(ProtobufCodec.encodeVarint(value))
    }
    
    public mutating func writeInt32Field(_ fieldNumber: Int, value: Int32) {
        let tag = UInt64((fieldNumber << 3) | Int(ProtobufWireType.varint.rawValue))
        data.append(ProtobufCodec.encodeVarint(tag))
        data.append(ProtobufCodec.encodeSignedVarint32(value))
    }
    
    public mutating func writeBoolField(_ fieldNumber: Int, value: Bool) {
        writeVarintField(fieldNumber, value: value ? 1 : 0)
    }
    
    public mutating func writeBytesField(_ fieldNumber: Int, bytes: Data) {
        let tag = UInt64((fieldNumber << 3) | Int(ProtobufWireType.lengthDelimited.rawValue))
        data.append(ProtobufCodec.encodeVarint(tag))
        data.append(ProtobufCodec.encodeVarint(UInt64(bytes.count)))
        data.append(bytes)
    }
    
    public mutating func writeStringField(_ fieldNumber: Int, string: String) {
        writeBytesField(fieldNumber, bytes: Data(string.utf8))
    }
    
    public mutating func writeMessageField(_ fieldNumber: Int, encode: (inout ProtobufWriter) -> Void) {
        var nested = ProtobufWriter()
        encode(&nested)
        writeBytesField(fieldNumber, bytes: nested.data)
    }
}

public struct ProtobufReader {
    private let data: Data
    private var offset: Data.Index
    
    public init(data: Data) {
        self.data = data
        self.offset = data.startIndex
    }
    
    public var hasMore: Bool {
        return offset < data.endIndex
    }
    
    public mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.endIndex {
            let byte = data[offset]
            offset = data.index(after: offset)
            if shift >= 64 {
                throw ProtobufDecodeError.malformedVarint
            }
            result |= UInt64(byte & 0x7F) << shift
            if (byte & 0x80) == 0 {
                return result
            }
            shift += 7
        }
        throw ProtobufDecodeError.truncatedData
    }
    
    public mutating func readNextField() throws -> (fieldNumber: Int, wireType: ProtobufWireType)? {
        guard hasMore else { return nil }
        let tag = try readVarint()
        let wireRaw = UInt8(tag & 0x07)
        guard let wireType = ProtobufWireType(rawValue: wireRaw) else {
            throw ProtobufDecodeError.unsupportedWireType(wireRaw)
        }
        let fieldNumber = Int(tag >> 3)
        guard fieldNumber > 0 else {
            throw ProtobufDecodeError.malformedVarint
        }
        return (fieldNumber, wireType)
    }
    
    public mutating func readLengthDelimited() throws -> Data {
        let len = try readVarint()
        guard len <= UInt64(Int.max) else {
            throw ProtobufDecodeError.messageTooLarge(Int.max)
        }
        let byteCount = Int(len)
        let remaining = data.distance(from: offset, to: data.endIndex)
        guard remaining >= byteCount else {
            throw ProtobufDecodeError.truncatedData
        }
        let end = data.index(offset, offsetBy: byteCount)
        let slice = Data(data[offset..<end])
        offset = end
        return slice
    }
    
    public mutating func skipField(wireType: ProtobufWireType) throws {
        switch wireType {
        case .varint:
            _ = try readVarint()
        case .fixed64:
            guard data.distance(from: offset, to: data.endIndex) >= 8 else { throw ProtobufDecodeError.truncatedData }
            offset = data.index(offset, offsetBy: 8)
        case .lengthDelimited:
            _ = try readLengthDelimited()
        case .fixed32:
            guard data.distance(from: offset, to: data.endIndex) >= 4 else { throw ProtobufDecodeError.truncatedData }
            offset = data.index(offset, offsetBy: 4)
        case .startGroup, .endGroup:
            throw ProtobufDecodeError.unsupportedWireType(wireType.rawValue)
        }
    }
}

// MARK: - Polo Pairing Protocol Messages (polo.proto)

public enum PoloStatus: UInt32, Equatable {
    case ok = 200
    case error = 400
    case badConfiguration = 401
    case badSecret = 402
}

public enum PoloEncodingType: UInt32, Equatable {
    case unknown = 0
    case alphanumeric = 1
    case numeric = 2
    case hexadecimal = 3
    case qrcode = 4
}

public enum PoloRoleType: UInt32, Equatable {
    case unknown = 0
    case input = 1
    case output = 2
}

public struct PoloEncoding: Equatable {
    public let type: PoloEncodingType
    public let symbolLength: UInt32
    
    public init(type: PoloEncodingType, symbolLength: UInt32) {
        self.type = type
        self.symbolLength = symbolLength
    }
    
    func encode(into w: inout ProtobufWriter) {
        w.writeVarintField(1, value: UInt64(type.rawValue))
        w.writeVarintField(2, value: UInt64(symbolLength))
    }
    
    static func decode(from data: Data) throws -> PoloEncoding {
        var r = ProtobufReader(data: data)
        var type: PoloEncodingType = .unknown
        var length: UInt32 = 0
        while let (field, wire) = try r.readNextField() {
            switch (field, wire) {
            case (1, .varint):
                let raw = UInt32(truncatingIfNeeded: try r.readVarint())
                type = PoloEncodingType(rawValue: raw) ?? .unknown
            case (2, .varint):
                length = UInt32(truncatingIfNeeded: try r.readVarint())
            default:
                try r.skipField(wireType: wire)
            }
        }
        return PoloEncoding(type: type, symbolLength: length)
    }
}

public struct PoloOptions: Equatable {
    public var inputEncodings: [PoloEncoding]
    public var outputEncodings: [PoloEncoding]
    public var preferredRole: PoloRoleType?
    
    public init(inputEncodings: [PoloEncoding] = [], outputEncodings: [PoloEncoding] = [], preferredRole: PoloRoleType? = nil) {
        self.inputEncodings = inputEncodings
        self.outputEncodings = outputEncodings
        self.preferredRole = preferredRole
    }
    
    func encode(into w: inout ProtobufWriter) {
        for enc in inputEncodings {
            w.writeMessageField(1) { enc.encode(into: &$0) }
        }
        for enc in outputEncodings {
            w.writeMessageField(2) { enc.encode(into: &$0) }
        }
        if let role = preferredRole {
            w.writeVarintField(3, value: UInt64(role.rawValue))
        }
    }
    
    static func decode(from data: Data) throws -> PoloOptions {
        var r = ProtobufReader(data: data)
        var opts = PoloOptions()
        while let (field, wire) = try r.readNextField() {
            switch (field, wire) {
            case (1, .lengthDelimited):
                let sub = try r.readLengthDelimited()
                opts.inputEncodings.append(try PoloEncoding.decode(from: sub))
            case (2, .lengthDelimited):
                let sub = try r.readLengthDelimited()
                opts.outputEncodings.append(try PoloEncoding.decode(from: sub))
            case (3, .varint):
                let raw = UInt32(truncatingIfNeeded: try r.readVarint())
                opts.preferredRole = PoloRoleType(rawValue: raw) ?? .unknown
            default:
                try r.skipField(wireType: wire)
            }
        }
        return opts
    }
}

public struct PoloConfiguration: Equatable {
    public let encoding: PoloEncoding
    public let clientRole: PoloRoleType
    
    public init(encoding: PoloEncoding, clientRole: PoloRoleType) {
        self.encoding = encoding
        self.clientRole = clientRole
    }
    
    func encode(into w: inout ProtobufWriter) {
        w.writeMessageField(1) { encoding.encode(into: &$0) }
        w.writeVarintField(2, value: UInt64(clientRole.rawValue))
    }
    
    static func decode(from data: Data) throws -> PoloConfiguration {
        var r = ProtobufReader(data: data)
        var encoding = PoloEncoding(type: .unknown, symbolLength: 0)
        var role: PoloRoleType = .unknown
        while let (field, wire) = try r.readNextField() {
            switch (field, wire) {
            case (1, .lengthDelimited):
                encoding = try PoloEncoding.decode(from: try r.readLengthDelimited())
            case (2, .varint):
                let raw = UInt32(truncatingIfNeeded: try r.readVarint())
                role = PoloRoleType(rawValue: raw) ?? .unknown
            default:
                try r.skipField(wireType: wire)
            }
        }
        return PoloConfiguration(encoding: encoding, clientRole: role)
    }
}

public struct PoloOuterMessage: Equatable {
    public enum Payload: Equatable {
        case pairingRequest(serviceName: String, clientName: String?)
        case pairingRequestAck(serverName: String?)
        case options(PoloOptions)
        case configuration(PoloConfiguration)
        case configurationAck
        case secret(Data)
        case secretAck(Data)
        case none
    }
    
    public var protocolVersion: UInt32
    public var statusRaw: UInt32
    public var payload: Payload
    
    public var status: PoloStatus? {
        PoloStatus(rawValue: statusRaw)
    }
    
    public init(protocolVersion: UInt32 = 2, status: PoloStatus = .ok, payload: Payload = .none) {
        self.protocolVersion = protocolVersion
        self.statusRaw = status.rawValue
        self.payload = payload
    }
    
    public init(protocolVersion: UInt32, statusRaw: UInt32, payload: Payload) {
        self.protocolVersion = protocolVersion
        self.statusRaw = statusRaw
        self.payload = payload
    }
    
    public func encode() -> Data {
        var w = ProtobufWriter()
        w.writeVarintField(1, value: UInt64(protocolVersion))
        w.writeVarintField(2, value: UInt64(statusRaw))
        switch payload {
        case .pairingRequest(let serviceName, let clientName):
            w.writeMessageField(10) { sub in
                sub.writeStringField(1, string: serviceName)
                if let clientName = clientName, !clientName.isEmpty {
                    sub.writeStringField(2, string: clientName)
                }
            }
        case .pairingRequestAck(let serverName):
            w.writeMessageField(11) { sub in
                if let serverName = serverName {
                    sub.writeStringField(1, string: serverName)
                }
            }
        case .options(let opts):
            w.writeMessageField(20) { opts.encode(into: &$0) }
        case .configuration(let cfg):
            w.writeMessageField(30) { cfg.encode(into: &$0) }
        case .configurationAck:
            w.writeMessageField(31) { _ in }
        case .secret(let bytes):
            w.writeMessageField(40) { $0.writeBytesField(1, bytes: bytes) }
        case .secretAck(let bytes):
            w.writeMessageField(41) { $0.writeBytesField(1, bytes: bytes) }
        case .none:
            break
        }
        return w.data
    }
    
    public static func decode(from data: Data) throws -> PoloOuterMessage {
        var r = ProtobufReader(data: data)
        var version: UInt32 = 1
        var statusRaw: UInt32 = PoloStatus.error.rawValue
        var payload: Payload = .none
        
        while let (field, wire) = try r.readNextField() {
            switch (field, wire) {
            case (1, .varint):
                version = UInt32(truncatingIfNeeded: try r.readVarint())
            case (2, .varint):
                statusRaw = UInt32(truncatingIfNeeded: try r.readVarint())
            case (10, .lengthDelimited):
                let subData = try r.readLengthDelimited()
                var sr = ProtobufReader(data: subData)
                var svc = ""
                var cli: String? = nil
                while let (sf, sw) = try sr.readNextField() {
                    switch (sf, sw) {
                    case (1, .lengthDelimited):
                        svc = String(data: try sr.readLengthDelimited(), encoding: .utf8) ?? ""
                    case (2, .lengthDelimited):
                        cli = String(data: try sr.readLengthDelimited(), encoding: .utf8)
                    default:
                        try sr.skipField(wireType: sw)
                    }
                }
                payload = .pairingRequest(serviceName: svc, clientName: cli)
            case (11, .lengthDelimited):
                let subData = try r.readLengthDelimited()
                var sr = ProtobufReader(data: subData)
                var srv: String? = nil
                while let (sf, sw) = try sr.readNextField() {
                    if sf == 1, sw == .lengthDelimited {
                        srv = String(data: try sr.readLengthDelimited(), encoding: .utf8)
                    } else {
                        try sr.skipField(wireType: sw)
                    }
                }
                payload = .pairingRequestAck(serverName: srv)
            case (20, .lengthDelimited):
                payload = .options(try PoloOptions.decode(from: try r.readLengthDelimited()))
            case (30, .lengthDelimited):
                payload = .configuration(try PoloConfiguration.decode(from: try r.readLengthDelimited()))
            case (31, .lengthDelimited):
                _ = try r.readLengthDelimited()
                payload = .configurationAck
            case (40, .lengthDelimited):
                let subData = try r.readLengthDelimited()
                var sr = ProtobufReader(data: subData)
                var bytes = Data()
                while let (sf, sw) = try sr.readNextField() {
                    if sf == 1, sw == .lengthDelimited {
                        bytes = try sr.readLengthDelimited()
                    } else {
                        try sr.skipField(wireType: sw)
                    }
                }
                payload = .secret(bytes)
            case (41, .lengthDelimited):
                let subData = try r.readLengthDelimited()
                var sr = ProtobufReader(data: subData)
                var bytes = Data()
                while let (sf, sw) = try sr.readNextField() {
                    if sf == 1, sw == .lengthDelimited {
                        bytes = try sr.readLengthDelimited()
                    } else {
                        try sr.skipField(wireType: sw)
                    }
                }
                payload = .secretAck(bytes)
            default:
                try r.skipField(wireType: wire)
            }
        }
        return PoloOuterMessage(protocolVersion: version, statusRaw: statusRaw, payload: payload)
    }
}

// MARK: - Remote Control Protocol Messages (remotemessage.proto)

public enum AndroidTVKeyCode: Int32, Equatable {
    case unknown = 0
    case home = 3
    case back = 4
    case dpadUp = 19
    case dpadDown = 20
    case dpadLeft = 21
    case dpadRight = 22
    case dpadCenter = 23
    case volumeUp = 24
    case volumeDown = 25
    case power = 26
    case space = 62
    case enter = 66
    case del = 67
    case menu = 82
    case search = 84
    case mediaPlayPause = 85
    case mediaStop = 86
    case mediaNext = 87
    case mediaPrevious = 88
    case mediaRewind = 89
    case mediaFastForward = 90
    case mute = 91
    case mediaPlay = 126
    case mediaPause = 127
    case volumeMute = 164
    case info = 165
    case channelUp = 166
    case channelDown = 167
    case settings = 176
    case sleep = 223
    case wakeup = 224
    case allApps = 284
    case refresh = 285
}

public enum AndroidTVKeyDirection: Int32, Equatable {
    case unknown = 0
    case startLong = 1
    case endLong = 2
    case short = 3
}

public struct AndroidTVFeature: OptionSet, Equatable {
    public let rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let ping    = AndroidTVFeature(rawValue: 1 << 0)
    public static let key     = AndroidTVFeature(rawValue: 1 << 1)
    public static let ime     = AndroidTVFeature(rawValue: 1 << 2)
    public static let voice   = AndroidTVFeature(rawValue: 1 << 3)
    public static let power   = AndroidTVFeature(rawValue: 1 << 5)
    public static let volume  = AndroidTVFeature(rawValue: 1 << 6)
    public static let appLink = AndroidTVFeature(rawValue: 1 << 9)
    
    public static let standardClient: AndroidTVFeature = [.ping, .key, .ime, .power, .volume, .appLink]
}

public struct AndroidTVDeviceInfo: Equatable {
    public var model: String = ""
    public var vendor: String = ""
    public var unknown1: Int32 = 0
    public var unknown2: String = ""
    public var packageName: String = ""
    public var appVersion: String = ""
    
    public init(
        model: String = "",
        vendor: String = "",
        unknown1: Int32 = 0,
        unknown2: String = "",
        packageName: String = "",
        appVersion: String = ""
    ) {
        self.model = model
        self.vendor = vendor
        self.unknown1 = unknown1
        self.unknown2 = unknown2
        self.packageName = packageName
        self.appVersion = appVersion
    }
    
    func encode(into w: inout ProtobufWriter) {
        if !model.isEmpty { w.writeStringField(1, string: model) }
        if !vendor.isEmpty { w.writeStringField(2, string: vendor) }
        if unknown1 != 0 { w.writeInt32Field(3, value: unknown1) }
        if !unknown2.isEmpty { w.writeStringField(4, string: unknown2) }
        if !packageName.isEmpty { w.writeStringField(5, string: packageName) }
        if !appVersion.isEmpty { w.writeStringField(6, string: appVersion) }
    }
    
    static func decode(from data: Data) throws -> AndroidTVDeviceInfo {
        var r = ProtobufReader(data: data)
        var info = AndroidTVDeviceInfo()
        while let (field, wire) = try r.readNextField() {
            switch (field, wire) {
            case (1, .lengthDelimited): info.model = String(data: try r.readLengthDelimited(), encoding: .utf8) ?? ""
            case (2, .lengthDelimited): info.vendor = String(data: try r.readLengthDelimited(), encoding: .utf8) ?? ""
            case (3, .varint): info.unknown1 = Int32(truncatingIfNeeded: try r.readVarint())
            case (4, .lengthDelimited): info.unknown2 = String(data: try r.readLengthDelimited(), encoding: .utf8) ?? ""
            case (5, .lengthDelimited): info.packageName = String(data: try r.readLengthDelimited(), encoding: .utf8) ?? ""
            case (6, .lengthDelimited): info.appVersion = String(data: try r.readLengthDelimited(), encoding: .utf8) ?? ""
            default: try r.skipField(wireType: wire)
            }
        }
        return info
    }
}

public struct AndroidTVVolumeInfo: Equatable {
    public var playerModel: String = ""
    public var volumeMax: UInt32 = 0
    public var volumeLevel: UInt32 = 0
    public var volumeMuted: Bool = false
    
    static func decode(from data: Data) throws -> AndroidTVVolumeInfo {
        var r = ProtobufReader(data: data)
        var vol = AndroidTVVolumeInfo()
        while let (field, wire) = try r.readNextField() {
            switch (field, wire) {
            case (3, .lengthDelimited): vol.playerModel = String(data: try r.readLengthDelimited(), encoding: .utf8) ?? ""
            case (6, .varint): vol.volumeMax = UInt32(truncatingIfNeeded: try r.readVarint())
            case (7, .varint): vol.volumeLevel = UInt32(truncatingIfNeeded: try r.readVarint())
            case (8, .varint): vol.volumeMuted = (try r.readVarint()) != 0
            default: try r.skipField(wireType: wire)
            }
        }
        return vol
    }
}

public struct AndroidTVImeKeyInjectInfo: Equatable {
    public var counter: Int32 = 0
    public var fieldCounter: Int32 = 0
    public var appPackage: String = ""
    public var appLabel: String = ""
    public var currentValue: String = ""
    
    static func decode(from data: Data) throws -> AndroidTVImeKeyInjectInfo {
        var r = ProtobufReader(data: data)
        var result = AndroidTVImeKeyInjectInfo()
        while let (field, wire) = try r.readNextField() {
            switch (field, wire) {
            case (1, .lengthDelimited):
                var sr = ProtobufReader(data: try r.readLengthDelimited())
                while let (sf, sw) = try sr.readNextField() {
                    switch (sf, sw) {
                    case (1, .varint): result.counter = Int32(truncatingIfNeeded: try sr.readVarint())
                    case (10, .lengthDelimited): result.appLabel = String(data: try sr.readLengthDelimited(), encoding: .utf8) ?? ""
                    case (12, .lengthDelimited): result.appPackage = String(data: try sr.readLengthDelimited(), encoding: .utf8) ?? ""
                    default: try sr.skipField(wireType: sw)
                    }
                }
            case (2, .lengthDelimited):
                var sr = ProtobufReader(data: try r.readLengthDelimited())
                while let (sf, sw) = try sr.readNextField() {
                    switch (sf, sw) {
                    case (1, .varint): result.fieldCounter = Int32(truncatingIfNeeded: try sr.readVarint())
                    case (2, .lengthDelimited): result.currentValue = String(data: try sr.readLengthDelimited(), encoding: .utf8) ?? ""
                    default: try sr.skipField(wireType: sw)
                    }
                }
            default:
                try r.skipField(wireType: wire)
            }
        }
        return result
    }
}

public enum AndroidTVRemoteMessage: Equatable {
    case remoteConfigure(code1: Int32, deviceInfo: AndroidTVDeviceInfo)
    case remoteSetActive(active: Int32)
    case remoteError(value: Bool)
    case remotePingRequest(val1: Int32, val2: Int32)
    case remotePingResponse(val1: Int32)
    case remoteKeyInject(keyCode: Int32, direction: AndroidTVKeyDirection)
    case remoteImeKeyInject(AndroidTVImeKeyInjectInfo)
    case remoteImeBatchEdit(imeCounter: Int32, fieldCounter: Int32, text: String)
    case remoteImeShowRequest(fieldCounter: Int32)
    case remoteStart(started: Bool)
    case remoteSetVolumeLevel(AndroidTVVolumeInfo)
    case remoteAppLinkLaunchRequest(appLink: String)
    case unknown
    
    public func encode() -> Data {
        var w = ProtobufWriter()
        switch self {
        case .remoteConfigure(let code1, let deviceInfo):
            w.writeMessageField(1) { sub in
                if code1 != 0 { sub.writeInt32Field(1, value: code1) }
                sub.writeMessageField(2) { deviceInfo.encode(into: &$0) }
            }
        case .remoteSetActive(let active):
            w.writeMessageField(2) { sub in
                if active != 0 { sub.writeInt32Field(1, value: active) }
            }
        case .remotePingRequest(let val1, let val2):
            w.writeMessageField(8) { sub in
                if val1 != 0 { sub.writeInt32Field(1, value: val1) }
                if val2 != 0 { sub.writeInt32Field(2, value: val2) }
            }
        case .remotePingResponse(let val1):
            w.writeMessageField(9) { sub in
                if val1 != 0 { sub.writeInt32Field(1, value: val1) }
            }
        case .remoteKeyInject(let keyCode, let direction):
            w.writeMessageField(10) { sub in
                if keyCode != 0 { sub.writeInt32Field(1, value: keyCode) }
                if direction != .unknown { sub.writeInt32Field(2, value: direction.rawValue) }
            }
        case .remoteImeBatchEdit(let imeCounter, let fieldCounter, let text):
            w.writeMessageField(21) { sub in
                if imeCounter != 0 { sub.writeInt32Field(1, value: imeCounter) }
                if fieldCounter != 0 { sub.writeInt32Field(2, value: fieldCounter) }
                sub.writeMessageField(3) { edit in
                    edit.writeInt32Field(1, value: 1) // insert = 1
                    edit.writeMessageField(2) { imeObj in
                        let charCount = Int32(text.utf16.count)
                        if charCount != 0 {
                            imeObj.writeInt32Field(1, value: charCount) // start
                            imeObj.writeInt32Field(2, value: charCount) // end
                        }
                        if !text.isEmpty {
                            imeObj.writeStringField(3, string: text)
                        }
                    }
                }
            }
        case .remoteAppLinkLaunchRequest(let appLink):
            w.writeMessageField(90) { sub in
                if !appLink.isEmpty { sub.writeStringField(1, string: appLink) }
            }
        case .remoteStart(let started):
            w.writeMessageField(40) { sub in
                if started { sub.writeBoolField(1, value: true) }
            }
        default:
            break
        }
        return w.data
    }
    
    public static func decode(from data: Data) throws -> AndroidTVRemoteMessage {
        var r = ProtobufReader(data: data)
        var result: AndroidTVRemoteMessage = .unknown
        while let (field, wire) = try r.readNextField() {
            guard wire == .lengthDelimited else {
                try r.skipField(wireType: wire)
                continue
            }
            let subData = try r.readLengthDelimited()
            switch field {
            case 1:
                var sr = ProtobufReader(data: subData)
                var code1: Int32 = 0
                var info = AndroidTVDeviceInfo()
                while let (sf, sw) = try sr.readNextField() {
                    switch (sf, sw) {
                    case (1, .varint): code1 = Int32(truncatingIfNeeded: try sr.readVarint())
                    case (2, .lengthDelimited): info = try AndroidTVDeviceInfo.decode(from: try sr.readLengthDelimited())
                    default: try sr.skipField(wireType: sw)
                    }
                }
                result = .remoteConfigure(code1: code1, deviceInfo: info)
            case 2:
                var sr = ProtobufReader(data: subData)
                var active: Int32 = 0
                while let (sf, sw) = try sr.readNextField() {
                    if sf == 1, sw == .varint {
                        active = Int32(truncatingIfNeeded: try sr.readVarint())
                    } else {
                        try sr.skipField(wireType: sw)
                    }
                }
                result = .remoteSetActive(active: active)
            case 3:
                var sr = ProtobufReader(data: subData)
                var errVal = false
                while let (sf, sw) = try sr.readNextField() {
                    if sf == 1, sw == .varint {
                        errVal = (try sr.readVarint()) != 0
                    } else {
                        try sr.skipField(wireType: sw)
                    }
                }
                result = .remoteError(value: errVal)
            case 8:
                var sr = ProtobufReader(data: subData)
                var v1: Int32 = 0
                var v2: Int32 = 0
                while let (sf, sw) = try sr.readNextField() {
                    switch (sf, sw) {
                    case (1, .varint): v1 = Int32(truncatingIfNeeded: try sr.readVarint())
                    case (2, .varint): v2 = Int32(truncatingIfNeeded: try sr.readVarint())
                    default: try sr.skipField(wireType: sw)
                    }
                }
                result = .remotePingRequest(val1: v1, val2: v2)
            case 9:
                var sr = ProtobufReader(data: subData)
                var v1: Int32 = 0
                while let (sf, sw) = try sr.readNextField() {
                    if sf == 1, sw == .varint {
                        v1 = Int32(truncatingIfNeeded: try sr.readVarint())
                    } else {
                        try sr.skipField(wireType: sw)
                    }
                }
                result = .remotePingResponse(val1: v1)
            case 10:
                var sr = ProtobufReader(data: subData)
                var kc: Int32 = 0
                var dir: AndroidTVKeyDirection = .unknown
                while let (sf, sw) = try sr.readNextField() {
                    switch (sf, sw) {
                    case (1, .varint): kc = Int32(truncatingIfNeeded: try sr.readVarint())
                    case (2, .varint): dir = AndroidTVKeyDirection(rawValue: Int32(truncatingIfNeeded: try sr.readVarint())) ?? .unknown
                    default: try sr.skipField(wireType: sw)
                    }
                }
                result = .remoteKeyInject(keyCode: kc, direction: dir)
            case 20:
                result = .remoteImeKeyInject(try AndroidTVImeKeyInjectInfo.decode(from: subData))
            case 21:
                var sr = ProtobufReader(data: subData)
                var ic: Int32 = 0
                var fc: Int32 = 0
                while let (sf, sw) = try sr.readNextField() {
                    switch (sf, sw) {
                    case (1, .varint): ic = Int32(truncatingIfNeeded: try sr.readVarint())
                    case (2, .varint): fc = Int32(truncatingIfNeeded: try sr.readVarint())
                    default: try sr.skipField(wireType: sw)
                    }
                }
                result = .remoteImeBatchEdit(imeCounter: ic, fieldCounter: fc, text: "")
            case 22:
                var sr = ProtobufReader(data: subData)
                var fc: Int32 = 0
                while let (sf, sw) = try sr.readNextField() {
                    if sf == 2, sw == .lengthDelimited {
                        var tfr = ProtobufReader(data: try sr.readLengthDelimited())
                        while let (tf, tw) = try tfr.readNextField() {
                            if tf == 1, tw == .varint {
                                fc = Int32(truncatingIfNeeded: try tfr.readVarint())
                            } else {
                                try tfr.skipField(wireType: tw)
                            }
                        }
                    } else {
                        try sr.skipField(wireType: sw)
                    }
                }
                result = .remoteImeShowRequest(fieldCounter: fc)
            case 40:
                var sr = ProtobufReader(data: subData)
                var started = false
                while let (sf, sw) = try sr.readNextField() {
                    if sf == 1, sw == .varint {
                        started = (try sr.readVarint()) != 0
                    } else {
                        try sr.skipField(wireType: sw)
                    }
                }
                result = .remoteStart(started: started)
            case 50:
                result = .remoteSetVolumeLevel(try AndroidTVVolumeInfo.decode(from: subData))
            case 90:
                var sr = ProtobufReader(data: subData)
                var link = ""
                while let (sf, sw) = try sr.readNextField() {
                    if sf == 1, sw == .lengthDelimited {
                        link = String(data: try sr.readLengthDelimited(), encoding: .utf8) ?? ""
                    } else {
                        try sr.skipField(wireType: sw)
                    }
                }
                result = .remoteAppLinkLaunchRequest(appLink: link)
            default:
                break
            }
        }
        return result
    }
}
