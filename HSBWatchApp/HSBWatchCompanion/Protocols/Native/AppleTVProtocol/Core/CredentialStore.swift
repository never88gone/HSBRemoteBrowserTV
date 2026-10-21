import Foundation
// import AppleTVLogging

/// Persists Companion pairing credentials as JSON files in Application Support and UserDefaults.
///
/// 采用双重容灾存储：沙盒文件系统 + UserDefaults 备份。
/// 支持设备名称大小写模糊容错，防止因前后空格、大小写差异导致的凭据丢失。
public struct CredentialStore {

    public init() {}

    private static let appDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        let dir = base.appendingPathComponent("AppleTVRemote", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)
        return dir
    }()

    private func normalizedKeys(for deviceID: String) -> [String] {
        var keys: [String] = []
        let raw = deviceID.replacingOccurrences(of: "/", with: "_")
        keys.append(raw)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keys.contains(trimmed) { keys.append(trimmed) }
        let lower = trimmed.lowercased()
        if !keys.contains(lower) { keys.append(lower) }
        return keys
    }

    private func url(for deviceID: String) -> URL {
        let safe = deviceID.replacingOccurrences(of: "/", with: "_")
        return Self.appDir.appendingPathComponent("\(safe).json")
    }

    private func airPlayURL(for deviceID: String) -> URL {
        let safe = deviceID.replacingOccurrences(of: "/", with: "_")
        return Self.appDir.appendingPathComponent("\(safe).airplay.json")
    }

    private func lockURL(for path: String) -> URL {
        Self.appDir.appendingPathComponent(
            (URL(fileURLWithPath: path).lastPathComponent) + ".lock")
    }

    // MARK: - File locking

    private func withExclusiveLock<T>(on path: String, body: () throws -> T) rethrows -> T {
        try withFileLock(on: path, kind: LOCK_EX, body: body)
    }

    private func withSharedLock<T>(on path: String, body: () throws -> T) rethrows -> T {
        try withFileLock(on: path, kind: LOCK_SH, body: body)
    }

    private func withFileLock<T>(on path: String, kind: Int32, body: () throws -> T) rethrows -> T {
        let lockPath = lockURL(for: path).path
        let fd = open(lockPath, O_CREAT | O_RDWR, 0o600)
        defer { if fd >= 0 { close(fd) } }
        if fd >= 0 { flock(fd, kind) }
        return try body()
    }

    // MARK: - Check

    public func hasCredentials(for deviceID: String) -> Bool {
        for k in normalizedKeys(for: deviceID) {
            if FileManager.default.fileExists(atPath: url(for: k).path) {
                return true
            }
            if UserDefaults.standard.data(forKey: "AppleTVRemote_\(k)") != nil {
                return true
            }
        }
        return false
    }

    public func hasAirPlayCredentials(for deviceID: String) -> Bool {
        for k in normalizedKeys(for: deviceID) {
            if FileManager.default.fileExists(atPath: airPlayURL(for: k).path) {
                return true
            }
        }
        return false
    }

    // MARK: - Save

    public func save(credentials: PairingCredentials, for deviceID: String) {
        guard let data = try? JSONEncoder().encode(credentials) else {
            Log.credentials.fail("CredentialStore: encode failed for \(deviceID)")
            return
        }
        
        let allKeys = Array(Set(normalizedKeys(for: deviceID) + normalizedKeys(for: credentials.deviceID)))
        
        for k in allKeys {
            UserDefaults.standard.set(data, forKey: "AppleTVRemote_\(k)")
            let path = url(for: k).path
            withExclusiveLock(on: path) {
                do {
                    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
                    Log.credentials.report("CredentialStore: saved credentials for \(k)")
                } catch {
                    Log.credentials.fail("CredentialStore: save failed: \(error)")
                }
            }
        }
        UserDefaults.standard.synchronize()
        NSLog("[CredentialStore] Successfully persisted credentials for device: %@ (and %d aliases)", deviceID, allKeys.count)
    }

    // MARK: - Load

    public func load(deviceID: String) -> PairingCredentials? {
        let candidates = normalizedKeys(for: deviceID)
        
        for k in candidates {
            let path = url(for: k).path
            if let creds = withSharedLock(on: path, body: { () -> PairingCredentials? in
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
                return try? JSONDecoder().decode(PairingCredentials.self, from: data)
            }) {
                return creds
            }
            
            if let data = UserDefaults.standard.data(forKey: "AppleTVRemote_\(k)"),
               let creds = try? JSONDecoder().decode(PairingCredentials.self, from: data) {
                // 回填到文件
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
                return creds
            }
        }
        
        return nil
    }

    // MARK: - Delete (只有在用户明确在设置中解除配对时调用)

    public func delete(deviceID: String) {
        for k in normalizedKeys(for: deviceID) {
            UserDefaults.standard.removeObject(forKey: "AppleTVRemote_\(k)")
            let path = url(for: k).path
            withExclusiveLock(on: path) {
                try? FileManager.default.removeItem(atPath: path)
                Log.credentials.report("CredentialStore: deleted credentials for \(k)")
            }
        }
        UserDefaults.standard.synchronize()
        NSLog("[CredentialStore] Explicitly deleted credentials for device: %@", deviceID)
    }

    // MARK: - AirPlay

    public func saveAirPlay(_ credentials: AirPlayCredentials, for deviceID: String) {
        guard let data = try? JSONEncoder().encode(credentials) else {
            Log.credentials.fail("CredentialStore: airplay encode failed for \(deviceID)")
            return
        }
        for k in normalizedKeys(for: deviceID) {
            let path = airPlayURL(for: k).path
            withExclusiveLock(on: path) {
                do {
                    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
                    Log.credentials.report("CredentialStore: saved airplay credentials for \(k)")
                } catch {
                    Log.credentials.fail("CredentialStore: airplay save failed: \(error)")
                }
            }
        }
    }

    public func loadAirPlay(deviceID: String) -> AirPlayCredentials? {
        for k in normalizedKeys(for: deviceID) {
            let path = airPlayURL(for: k).path
            if let creds = withSharedLock(on: path, body: { () -> AirPlayCredentials? in
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
                return try? JSONDecoder().decode(AirPlayCredentials.self, from: data)
            }) {
                return creds
            }
        }
        return nil
    }

    public func deleteAirPlay(deviceID: String) {
        for k in normalizedKeys(for: deviceID) {
            let path = airPlayURL(for: k).path
            withExclusiveLock(on: path) {
                try? FileManager.default.removeItem(atPath: path)
                Log.credentials.report("CredentialStore: deleted airplay credentials for \(k)")
            }
        }
    }
}

/// Credentials obtained after a successful Companion pairing handshake.
public struct PairingCredentials: Codable {
    public let clientID: String      // UUID this client registered with
    public let ltsk: Data            // Long-term secret key (Ed25519 private key bytes)
    public let ltpk: Data            // Long-term public key (Ed25519 public key bytes)
    public let deviceLTPK: Data      // Apple TV's long-term public key
    public let deviceID: String      // Apple TV's pairing identifier
    /// Name sent in HAP pair-setup M5 tag=0x11 and `_systemInfo` `name` field.
    /// Must match what was used at pair-setup time.
    public let name: String

    public init(clientID: String, ltsk: Data, ltpk: Data, deviceLTPK: Data, deviceID: String,
                name: String = "Mac Remote") {
        self.clientID = clientID
        self.ltsk = ltsk
        self.ltpk = ltpk
        self.deviceLTPK = deviceLTPK
        self.deviceID = deviceID
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clientID   = try c.decode(String.self, forKey: .clientID)
        ltsk       = try c.decode(Data.self,   forKey: .ltsk)
        ltpk       = try c.decode(Data.self,   forKey: .ltpk)
        deviceLTPK = try c.decode(Data.self,   forKey: .deviceLTPK)
        deviceID   = try c.decode(String.self, forKey: .deviceID)
        name       = (try? c.decode(String.self, forKey: .name)) ?? "Mac Remote"
    }
}
