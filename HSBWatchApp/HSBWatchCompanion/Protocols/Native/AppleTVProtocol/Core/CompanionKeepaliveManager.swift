import Foundation

/// CompanionKeepaliveManager
/// 负责 Apple TV Companion 会话的心跳保活探测与文本输入存活检查
@MainActor
public final class CompanionKeepaliveManager {
    private weak var session: CompanionSession?
    private var keepaliveTimer: DispatchSourceTimer?

    public init(session: CompanionSession) {
        self.session = session
    }

    public func start() {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        // 关键保活：Apple TV (tvOS) 默认会在无操作 30 秒左右断开 TCP 空闲连接。
        // 将心跳周期缩短至 10 秒，持续发送活跃探测包，保持连接长效稳定。
        timer.schedule(deadline: .now() + 10.0, repeating: 10.0)
        timer.setEventHandler { [weak self] in
            guard let self, let session = self.session else { return }
            let txn = session.nextTxn()
            session.sendEncrypted(OPACK.encodeFetchAttentionState(txn: txn))
            if session.currentTextInputData != nil {
                // Skip the stop+start poll if the user typed within the last
                // keepalive interval — recent activity already confirms the
                // keyboard is alive, and racing the poll's stale-UUID window
                // against a user send breaks sendText with sessionUUIDMissing.
                if let last = session.lastTextOpAt,
                   Date().timeIntervalSince(last) < 10 {
                    return
                }
                let stopTxn = session.nextTxn()
                session.sendEncrypted(OPACK.encodeTextInputStop(txn: stopTxn))
                let tiTxn = session.nextTxn()
                session.registerCallback(txn: tiTxn) { [weak session] resp in
                    guard let session else { return }
                    let tiD = (resp["_c"] as? [String: Any])?["_tiD"] as? Data
                    session.currentTextInputData = tiD
                    if tiD == nil {
                        Log.companion.report("Companion: keyboard inactive (poll detected no text field)")
                        session.delegate?.sessionDidChangeKeyboardActive(false, data: nil)
                    }
                }
                session.sendEncrypted(OPACK.encodeTextInputStart(txn: tiTxn))
            }
        }
        timer.resume()
        keepaliveTimer = timer
    }

    public func stop() {
        keepaliveTimer?.cancel()
        keepaliveTimer = nil
    }
}
