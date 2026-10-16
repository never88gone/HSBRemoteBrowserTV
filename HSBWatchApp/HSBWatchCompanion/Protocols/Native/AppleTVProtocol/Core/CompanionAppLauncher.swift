import Foundation

/// CompanionAppLauncher
/// 负责 Apple TV 应用列表获取与应用拉起业务调度
@MainActor
public final class CompanionAppLauncher {
    private weak var session: CompanionSession?

    public init(session: CompanionSession) {
        self.session = session
    }

    public func fetchApps(completion: ((Result<[(id: String, name: String)], Error>) -> Void)? = nil) {
        guard let session else {
            completion?(.failure(CompanionError.notConnected))
            return
        }
        let txn = session.nextTxn()
        Log.companion.report("Companion: fetchApps txn=\(txn)")
        let timeoutItem = DispatchWorkItem { [weak self, weak session] in
            guard let self, let session else { return }
            if session.removeCallback(txn: txn) != nil {
                Log.companion.report("Companion: fetchApps timed out (no response from ATV)")
                completion?(.failure(CompanionError.unexpectedResponse))
            }
        }
        session.registerCallback(txn: txn) { [weak self, weak session] response in
            timeoutItem.cancel()
            guard let self, let session else { return }
            let cVal = response["_c"]
            Log.companion.report("Companion: fetchApps callback fired, _c type=\(type(of: cVal))")
            guard let content = response["_c"] as? [String: Any] else {
                Log.companion.report("Companion: fetchApps — unexpected response format")
                completion?(.failure(CompanionError.unexpectedResponse))
                return
            }
            let apps = content.compactMap { (key, value) -> (id: String, name: String)? in
                guard let name = value as? String else { return nil }
                return (id: key, name: name)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            session.delegate?.sessionDidFetchApps(apps)
            completion?(.success(apps))
        }
        session.sendEncrypted(OPACK.encodeFetchLaunchableApplicationsEvent(txn: txn))
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeoutItem)
    }

    public func launchApp(bundleID: String,
                          completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let session else {
            completion?(.failure(CompanionError.notConnected))
            return
        }
        let txn = session.nextTxn()
        Log.companion.report("Companion: launching app \(bundleID) txn=\(txn)")
        let timeoutItem = DispatchWorkItem { [weak self, weak session] in
            guard let self, let session else { return }
            if session.removeCallback(txn: txn) != nil {
                Log.companion.report("Companion: launchApp \(bundleID) timed out")
                completion?(.failure(CompanionError.unexpectedResponse))
            }
        }
        session.registerCallback(txn: txn) { _ in
            timeoutItem.cancel()
            completion?(.success(()))
        }
        session.sendEncrypted(OPACK.encodeLaunchApp(bundleID: bundleID, txn: txn))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeoutItem)
    }
}
