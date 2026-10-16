//
//  CompanionTextInputController.swift
//  HSBWatchCompanion
//

import Foundation

@MainActor
public final class CompanionTextInputController {
    public weak var session: CompanionSession?
    public var currentTextInputData: Data?
    public var lastTextOpAt: Date?
    
    public init(session: CompanionSession) {
        self.session = session
    }
    
    public func reset() {
        currentTextInputData = nil
        lastTextOpAt = nil
    }
    
    public func sendText(_ text: String, completion: @escaping (Error?) -> Void) {
        guard let session else {
            completion(TextInputError.notConnected); return
        }
        guard let tiD = currentTextInputData else {
            completion(TextInputError.noActiveTextField); return
        }
        guard let uuid = RTITextOperations.extractSessionUUID(from: tiD) else {
            completion(TextInputError.sessionUUIDMissing); return
        }
        lastTextOpAt = Date()
        let payload = RTITextOperations.inputPayload(sessionUUID: uuid, text: text)
        session.sendEncrypted(OPACK.encodeTextInputCommand(tiD: payload, txn: session.nextTxn()))
        Log.companion.report("Companion: sent text input (\(text.count) chars)")
        completion(nil)
    }

    public func sendBackspace(completion: @escaping (Error?) -> Void) {
        guard let session else {
            completion(TextInputError.notConnected); return
        }
        lastTextOpAt = Date()
        let stopTxn = session.nextTxn()
        session.sendEncrypted(OPACK.encodeTextInputStop(txn: stopTxn))
        let startTxn = session.nextTxn()
        session.registerCallback(for: startTxn) { [weak self] response in
            guard let self, let session = self.session else { return }
            guard let tiD = (response["_c"] as? [String: Any])?["_tiD"] as? Data else {
                completion(TextInputError.noActiveTextField); return
            }
            self.currentTextInputData = tiD
            guard let uuid = RTITextOperations.extractSessionUUID(from: tiD) else {
                completion(TextInputError.sessionUUIDMissing); return
            }
            let current = RTITextOperations.extractCurrentText(from: tiD) ?? ""
            let updated = String(current.dropLast())
            let payload = RTITextOperations.assertPayload(sessionUUID: uuid, text: updated)
            session.sendEncrypted(OPACK.encodeTextInputCommand(tiD: payload, txn: session.nextTxn()))
            Log.companion.report("Companion: sent backspace (was \(current.count) chars)")
            completion(nil)
        }
        session.sendEncrypted(OPACK.encodeTextInputStart(txn: startTxn))
    }

    public func sendClearText(completion: @escaping (Error?) -> Void) {
        guard let session else {
            completion(TextInputError.notConnected); return
        }
        lastTextOpAt = Date()
        let stopTxn = session.nextTxn()
        session.sendEncrypted(OPACK.encodeTextInputStop(txn: stopTxn))
        let startTxn = session.nextTxn()
        session.registerCallback(for: startTxn) { [weak self] response in
            guard let self, let session = self.session else { return }
            guard let tiD = (response["_c"] as? [String: Any])?["_tiD"] as? Data else {
                completion(TextInputError.noActiveTextField); return
            }
            self.currentTextInputData = tiD
            guard let uuid = RTITextOperations.extractSessionUUID(from: tiD) else {
                completion(TextInputError.sessionUUIDMissing); return
            }
            let payload = RTITextOperations.clearPayload(sessionUUID: uuid)
            session.sendEncrypted(OPACK.encodeTextInputCommand(tiD: payload, txn: session.nextTxn()))
            Log.companion.report("Companion: sent clear text input")
            completion(nil)
        }
        session.sendEncrypted(OPACK.encodeTextInputStart(txn: startTxn))
    }
}
