//
//  AndroidTVCertificateManager.swift
//  HSBWatchCompanion
//
//  负责生成、持久化管理 Android TV Remote v2 客户端 RSA-2048 自签名 X.509 v3 证书与 SecIdentity，
//  提取客户端/服务端证书 RSA 公钥模数与指数，严格校验与计算 Polo 协议 SHA-256 配对秘密，
//  以及保存/查询已配对 Android TV 设备凭证。
//

import Foundation
import Security
import CryptoKit
import CommonCrypto

public enum AndroidTVPairingError: Error, LocalizedError {
    case certificateGenerationFailed(String)
    case identityUnavailable(String)
    case invalidPINFormat
    case pinMismatch
    case missingServerCertificate
    case invalidRSAPublicKey(String)
    
    public var errorDescription: String? {
        switch self {
        case .certificateGenerationFailed(let detail):
            return "生成客户端配对证书失败: \(detail)"
        case .identityUnavailable(let detail):
            return "无法获取客户端 TLS 身份凭证: \(detail)"
        case .invalidPINFormat:
            return "配对码格式错误，请输入电视上显示的 6 位十六进制配对码。"
        case .pinMismatch:
            return "配对码校验失败，请重新核对电视屏幕显示的 6 位配对码。"
        case .missingServerCertificate:
            return "TLS 握手未能获取 Android TV 服务端证书。"
        case .invalidRSAPublicKey(let detail):
            return "解析 RSA 公钥参数失败: \(detail)"
        }
    }
}

public struct AndroidTVPairedRecord: Codable, Equatable {
    public let deviceKey: String
    public let deviceName: String
    public let host: String
    public let port: UInt16
    public let serverCertSHA256: String
    public let pairedAt: Date
}

public final class AndroidTVCertificateManager {
    public static let shared = AndroidTVCertificateManager()
    
    private static let keyTag = "com.never88gone.thlbrowserios.androidtv.clientkey.v1"
    private static let certLabel = "com.never88gone.thlbrowserios.androidtv.clientcert.v1"
    private static let certDERDefaultsKey = "HSBAndroidTVClientCertDER_v1"
    private static let pairedRecordsDefaultsKey = "HSBAndroidTVPairedRecords_v1"
    
    private let lock = NSLock()
    private var cachedIdentity: SecIdentity?
    private var cachedCertDER: Data?
    
    public init() {}
    
    // MARK: - Client Identity & Self-Signed X.509 v3 RSA-2048 Certificate
    
    public func loadOrCreateClientIdentity() throws -> (identity: SecIdentity, certDER: Data) {
        lock.lock()
        defer { lock.unlock() }
        
        if let cachedIdentity, let cachedCertDER {
            return (cachedIdentity, cachedCertDER)
        }
        
        if let savedCertDER = UserDefaults.standard.data(forKey: Self.certDERDefaultsKey),
           let existingIdentity = findIdentityMatching(certDER: savedCertDER) {
            self.cachedIdentity = existingIdentity
            self.cachedCertDER = savedCertDER
            return (existingIdentity, savedCertDER)
        }
        
        // 若不完整则清理旧残留后重新生成
        cleanupStoredKeychainItems()
        
        let tagData = Data(Self.keyTag.utf8)
        let privateKeyAttrs: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrLabel as String: Self.keyTag,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let keyParams: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: privateKeyAttrs
        ]
        
        var keyErr: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyParams as CFDictionary, &keyErr),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            let desc = keyErr?.takeRetainedValue().localizedDescription ?? "SecKeyCreateRandomKey returned nil"
            throw AndroidTVPairingError.certificateGenerationFailed(desc)
        }
        
        var pubErr: Unmanaged<CFError>?
        guard let pubKeyPKCS1 = SecKeyCopyExternalRepresentation(publicKey, &pubErr) as Data? else {
            let desc = pubErr?.takeRetainedValue().localizedDescription ?? "SecKeyCopyExternalRepresentation returned nil"
            throw AndroidTVPairingError.certificateGenerationFailed(desc)
        }
        
        let certDER = try Self.buildSelfSignedX509CertificateDER(
            commonName: "atvremote",
            publicKeyPKCS1: pubKeyPKCS1,
            signWith: privateKey
        )
        
        guard let cert = SecCertificateCreateWithData(nil, certDER as CFData) else {
            throw AndroidTVPairingError.certificateGenerationFailed("SecCertificateCreateWithData failed")
        }
        
        let certAddQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: cert,
            kSecAttrLabel as String: Self.certLabel,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let addStatus = SecItemAdd(certAddQuery as CFDictionary, nil)
        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            throw AndroidTVPairingError.identityUnavailable("SecItemAdd cert failed with OSStatus \(addStatus)")
        }
        
        UserDefaults.standard.set(certDER, forKey: Self.certDERDefaultsKey)
        
        guard let identity = findIdentityMatching(certDER: certDER) else {
            throw AndroidTVPairingError.identityUnavailable("SecIdentity query returned no matching identity")
        }
        
        self.cachedIdentity = identity
        self.cachedCertDER = certDER
        return (identity, certDER)
    }
    
    private func findIdentityMatching(certDER: Data) -> SecIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [SecIdentity] else {
            return nil
        }
        for identity in items {
            var certRef: SecCertificate?
            if SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess,
               let cert = certRef {
                let data = SecCertificateCopyData(cert) as Data
                if data == certDER {
                    return identity
                }
            }
        }
        return nil
    }
    
    private func cleanupStoredKeychainItems() {
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Data(Self.keyTag.utf8)
        ]
        SecItemDelete(keyQuery as CFDictionary)
        
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: Self.certLabel
        ]
        SecItemDelete(certQuery as CFDictionary)
        UserDefaults.standard.removeObject(forKey: Self.certDERDefaultsKey)
    }
    
    // MARK: - Paired Devices Store
    
    public func isPaired(deviceKey: String) -> Bool {
        return pairedRecord(for: deviceKey) != nil
    }
    
    public func pairedRecord(for deviceKey: String) -> AndroidTVPairedRecord? {
        let map = loadPairedRecordsMap()
        return map[deviceKey]
    }
    
    public func savePairedRecord(deviceKey: String, deviceName: String, host: String, port: UInt16, serverCertDER: Data) {
        let sha256Hex = SHA256.hash(data: serverCertDER).map { String(format: "%02x", $0) }.joined()
        var map = loadPairedRecordsMap()
        map[deviceKey] = AndroidTVPairedRecord(
            deviceKey: deviceKey,
            deviceName: deviceName,
            host: host,
            port: port,
            serverCertSHA256: sha256Hex,
            pairedAt: Date()
        )
        savePairedRecordsMap(map)
    }
    
    public func removePairedRecord(for deviceKey: String) {
        var map = loadPairedRecordsMap()
        if map.removeValue(forKey: deviceKey) != nil {
            savePairedRecordsMap(map)
        }
    }
    
    public func allPairedRecords() -> [AndroidTVPairedRecord] {
        return Array(loadPairedRecordsMap().values)
    }
    
    private func loadPairedRecordsMap() -> [String: AndroidTVPairedRecord] {
        guard let data = UserDefaults.standard.data(forKey: Self.pairedRecordsDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: AndroidTVPairedRecord].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    private func savePairedRecordsMap(_ map: [String: AndroidTVPairedRecord]) {
        if let encoded = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(encoded, forKey: Self.pairedRecordsDefaultsKey)
        }
    }
    
    // MARK: - Pairing Secret SHA-256 Computation (Google Polo Protocol)
    
    /// 根据 Google Polo 协议计算配对校验秘钥：
    /// SHA256(clientModulus + clientExponent + serverModulus + serverExponent + hexBytes(pin[2..<6]))
    /// 并且校验 hash[0] == UInt8(pin[0..<2], radix: 16)
    public static func computePairingSecret(
        clientCertDER: Data,
        serverCertDER: Data,
        pinCode: String
    ) throws -> Data {
        let normalizedPIN = pinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalizedPIN.count == 6,
              let checkByte = UInt8(normalizedPIN.prefix(2), radix: 16),
              let nonceBytes = dataFromHexString(String(normalizedPIN.dropFirst(2))),
              nonceBytes.count == 2 else {
            throw AndroidTVPairingError.invalidPINFormat
        }
        
        let (clientMod, clientExp) = try extractRSAPublicKeyComponents(fromX509CertDER: clientCertDER)
        let (serverMod, serverExp) = try extractRSAPublicKeyComponents(fromX509CertDER: serverCertDER)
        
        var hasher = SHA256()
        hasher.update(data: clientMod)
        hasher.update(data: clientExp)
        hasher.update(data: serverMod)
        hasher.update(data: serverExp)
        hasher.update(data: nonceBytes)
        let digest = Data(hasher.finalize())
        
        guard digest.first == checkByte else {
            throw AndroidTVPairingError.pinMismatch
        }
        return digest
    }
    
    public static func extractRSAPublicKeyComponents(fromX509CertDER certDER: Data) throws -> (modulus: Data, exponent: Data) {
        // 路径 1：优先尝试系统 SecCertificate 提取 PKCS#1 公钥数据
        if let cert = SecCertificateCreateWithData(nil, certDER as CFData),
           let pubKey = SecCertificateCopyKey(cert),
           let pkcs1 = SecKeyCopyExternalRepresentation(pubKey, nil) as Data?,
           let parsed = try? parsePKCS1RSAPublicKey(pkcs1) {
            return parsed
        }
        // 路径 2：纯 ASN.1 DER X.509 结构体解析兜底
        return try parseRSAComponentsFromX509DER(certDER)
    }
    
    public static func parsePKCS1RSAPublicKey(_ pkcs1DER: Data) throws -> (modulus: Data, exponent: Data) {
        var reader = ASN1Reader(data: pkcs1DER)
        let seq = try reader.readTLV(expectedTag: 0x30)
        var seqReader = ASN1Reader(data: seq.value)
        let modTLV = try seqReader.readTLV(expectedTag: 0x02)
        let expTLV = try seqReader.readTLV(expectedTag: 0x02)
        return (stripLeadingZeros(modTLV.value), stripLeadingZeros(expTLV.value))
    }
    
    private static func parseRSAComponentsFromX509DER(_ certDER: Data) throws -> (modulus: Data, exponent: Data) {
        var root = ASN1Reader(data: certDER)
        let certSeq = try root.readTLV(expectedTag: 0x30)
        var certReader = ASN1Reader(data: certSeq.value)
        let tbsSeq = try certReader.readTLV(expectedTag: 0x30)
        var tbsReader = ASN1Reader(data: tbsSeq.value)
        
        // version [0] EXPLICIT OPTIONAL
        if tbsReader.peekTag() == 0xA0 {
            _ = try tbsReader.readTLV(expectedTag: 0xA0)
        }
        _ = try tbsReader.readTLV(expectedTag: 0x02) // serialNumber
        _ = try tbsReader.readTLV(expectedTag: 0x30) // signature AlgorithmIdentifier
        _ = try tbsReader.readTLV(expectedTag: 0x30) // issuer
        _ = try tbsReader.readTLV(expectedTag: 0x30) // validity
        _ = try tbsReader.readTLV(expectedTag: 0x30) // subject
        
        // SubjectPublicKeyInfo ::= SEQUENCE { algorithm AlgorithmIdentifier, subjectPublicKey BIT STRING }
        let spki = try tbsReader.readTLV(expectedTag: 0x30)
        var spkiReader = ASN1Reader(data: spki.value)
        _ = try spkiReader.readTLV(expectedTag: 0x30) // algorithm
        let bitString = try spkiReader.readTLV(expectedTag: 0x03)
        guard bitString.value.count > 1 else {
            throw AndroidTVPairingError.invalidRSAPublicKey("SubjectPublicKey BIT STRING empty")
        }
        // 首字节为 unused bits count (0x00)
        let pkcs1 = Data(bitString.value.dropFirst())
        return try parsePKCS1RSAPublicKey(pkcs1)
    }
    
    private static func stripLeadingZeros(_ data: Data) -> Data {
        var idx = data.startIndex
        while idx < data.endIndex && data[idx] == 0x00 {
            let next = data.index(after: idx)
            if next == data.endIndex {
                break
            }
            idx = next
        }
        return Data(data[idx..<data.endIndex])
    }
    
    private static func dataFromHexString(_ hex: String) -> Data? {
        let chars = Array(hex)
        guard chars.count % 2 == 0 else { return nil }
        var data = Data(capacity: chars.count / 2)
        var i = 0
        while i < chars.count {
            let pair = String(chars[i...i+1])
            guard let byte = UInt8(pair, radix: 16) else { return nil }
            data.append(byte)
            i += 2
        }
        return data
    }
    
    // MARK: - X.509 v3 DER Self-Signed Certificate Builder
    
    public static func buildSelfSignedX509CertificateDER(
        commonName: String,
        publicKeyPKCS1: Data,
        signWith privateKey: SecKey
    ) throws -> Data {
        // 1. version [0] EXPLICIT INTEGER 2 (v3)
        let version = derExplicitTag(0xA0, content: derInteger(Data([0x02])))
        
        // 2. serialNumber (8 bytes positive random integer)
        var serialBytes = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, serialBytes.count, &serialBytes)
        serialBytes[0] &= 0x7F
        if serialBytes[0] == 0 { serialBytes[0] = 0x01 }
        let serialNumber = derInteger(Data(serialBytes))
        
        // 3. signature AlgorithmIdentifier: sha256WithRSAEncryption (1.2.840.113549.1.1.11) + NULL
        let sha256WithRSAOID: [UInt8] = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B]
        let derNull: [UInt8] = [0x05, 0x00]
        let sigAlgId = derSequence(Data(sha256WithRSAOID) + Data(derNull))
        
        // 4. Name (Issuer & Subject): CN = commonName
        let cnOID: [UInt8] = [0x06, 0x03, 0x55, 0x04, 0x03] // 2.5.4.3
        let cnStr = derTLV(tag: 0x0C, content: Data(commonName.utf8)) // UTF8String
        let attrTypeAndValue = derSequence(Data(cnOID) + cnStr)
        let rdnSet = derTLV(tag: 0x31, content: attrTypeAndValue)
        let x509Name = derSequence(rdnSet)
        
        // 5. Validity: now - 1 day to now + 10 years
        let now = Date()
        let notBeforeDate = now.addingTimeInterval(-86400)
        let notAfterDate = Calendar(identifier: .gregorian).date(byAdding: .year, value: 10, to: now) ?? now.addingTimeInterval(10 * 365 * 86400)
        let validity = derSequence(derX509Time(notBeforeDate) + derX509Time(notAfterDate))
        
        // 6. SubjectPublicKeyInfo: rsaEncryption (1.2.840.113549.1.1.1) + NULL + BIT STRING(0x00 + PKCS#1)
        let rsaEncryptionOID: [UInt8] = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]
        let pubAlgId = derSequence(Data(rsaEncryptionOID) + Data(derNull))
        let pubBitString = derBitString(publicKeyPKCS1)
        let spki = derSequence(pubAlgId + pubBitString)
        
        // 7. Extensions [3] EXPLICIT: BasicConstraints (CA:TRUE, pathlen:0) + SubjectAltName (DNS:commonName)
        let basicConstraintsOID: [UInt8] = [0x06, 0x03, 0x55, 0x1D, 0x13] // 2.5.29.19
        let bcValue = derSequence(derTLV(tag: 0x01, content: Data([0xFF])) + derInteger(Data([0x00])))
        let bcExt = derSequence(Data(basicConstraintsOID) + derOctetString(bcValue))
        
        let sanOID: [UInt8] = [0x06, 0x03, 0x55, 0x1D, 0x11] // 2.5.29.17
        let sanDNSName = derTLV(tag: 0x82, content: Data(commonName.utf8)) // dNSName [2] IA5String
        let sanExt = derSequence(Data(sanOID) + derOctetString(derSequence(sanDNSName)))
        
        let extensions = derExplicitTag(0xA3, content: derSequence(bcExt + sanExt))
        
        // Assemble TBSCertificate
        var tbsContent = Data()
        tbsContent.append(version)
        tbsContent.append(serialNumber)
        tbsContent.append(sigAlgId)
        tbsContent.append(x509Name)
        tbsContent.append(validity)
        tbsContent.append(x509Name)
        tbsContent.append(spki)
        tbsContent.append(extensions)
        let tbsCertificate = derSequence(tbsContent)
        
        // Sign TBSCertificate with SHA256withRSA (PKCS#1 v1.5)
        var signErr: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            tbsCertificate as CFData,
            &signErr
        ) as Data? else {
            let desc = signErr?.takeRetainedValue().localizedDescription ?? "SecKeyCreateSignature failed"
            throw AndroidTVPairingError.certificateGenerationFailed(desc)
        }
        
        // Final X.509 Certificate
        return derSequence(tbsCertificate + sigAlgId + derBitString(signature))
    }
    
    // MARK: - DER Helpers
    
    private static func derLength(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }
        var lenBytes: [UInt8] = []
        var v = length
        while v > 0 {
            lenBytes.insert(UInt8(v & 0xFF), at: 0)
            v >>= 8
        }
        var out = Data([0x80 | UInt8(lenBytes.count)])
        out.append(contentsOf: lenBytes)
        return out
    }
    
    private static func derTLV(tag: UInt8, content: Data) -> Data {
        var out = Data([tag])
        out.append(derLength(content.count))
        out.append(content)
        return out
    }
    
    private static func derSequence(_ content: Data) -> Data {
        derTLV(tag: 0x30, content: content)
    }
    
    private static func derExplicitTag(_ tag: UInt8, content: Data) -> Data {
        derTLV(tag: tag, content: content)
    }
    
    private static func derOctetString(_ content: Data) -> Data {
        derTLV(tag: 0x04, content: content)
    }
    
    private static func derBitString(_ content: Data) -> Data {
        var body = Data([0x00]) // 0 unused bits
        body.append(content)
        return derTLV(tag: 0x03, content: body)
    }
    
    private static func derInteger(_ unsignedBytes: Data) -> Data {
        var bytes = unsignedBytes
        if bytes.isEmpty {
            bytes = Data([0x00])
        } else if (bytes.first! & 0x80) != 0 {
            bytes.insert(0x00, at: bytes.startIndex)
        }
        return derTLV(tag: 0x02, content: bytes)
    }
    
    private static func derX509Time(_ date: Date) -> Data {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if year < 2050 {
            formatter.dateFormat = "yyMMddHHmmss'Z'"
            return derTLV(tag: 0x17, content: Data(formatter.string(from: date).utf8)) // UTCTime
        } else {
            formatter.dateFormat = "yyyyMMddHHmmss'Z'"
            return derTLV(tag: 0x18, content: Data(formatter.string(from: date).utf8)) // GeneralizedTime
        }
    }
}

// MARK: - Lightweight ASN.1 DER Reader

private struct ASN1Reader {
    private let data: Data
    private var offset: Data.Index
    
    init(data: Data) {
        self.data = data
        self.offset = data.startIndex
    }
    
    func peekTag() -> UInt8? {
        guard offset < data.endIndex else { return nil }
        return data[offset]
    }
    
    mutating func readTLV(expectedTag: UInt8? = nil) throws -> (tag: UInt8, value: Data) {
        guard offset < data.endIndex else {
            throw AndroidTVPairingError.invalidRSAPublicKey("ASN.1 unexpected EOF")
        }
        let tag = data[offset]
        offset = data.index(after: offset)
        if let expected = expectedTag, tag != expected {
            throw AndroidTVPairingError.invalidRSAPublicKey("ASN.1 expected tag 0x\(String(tag: expected)) got 0x\(String(tag: tag))")
        }
        guard offset < data.endIndex else {
            throw AndroidTVPairingError.invalidRSAPublicKey("ASN.1 truncated length")
        }
        let firstLen = data[offset]
        offset = data.index(after: offset)
        let contentLen: Int
        if (firstLen & 0x80) == 0 {
            contentLen = Int(firstLen)
        } else {
            let count = Int(firstLen & 0x7F)
            guard count > 0, count <= 4, data.distance(from: offset, to: data.endIndex) >= count else {
                throw AndroidTVPairingError.invalidRSAPublicKey("ASN.1 invalid long-form length")
            }
            var acc = 0
            for _ in 0..<count {
                acc = (acc << 8) | Int(data[offset])
                offset = data.index(after: offset)
            }
            contentLen = acc
        }
        guard data.distance(from: offset, to: data.endIndex) >= contentLen else {
            throw AndroidTVPairingError.invalidRSAPublicKey("ASN.1 truncated value")
        }
        let end = data.index(offset, offsetBy: contentLen)
        let value = Data(data[offset..<end])
        offset = end
        return (tag, value)
    }
}

private extension String {
    init(tag: UInt8) {
        self = String(format: "%02X", tag)
    }
}
