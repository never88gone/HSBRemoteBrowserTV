//
//  AndroidTVPairingSession.swift
//  HSBWatchCompanion
//
//  实现 Google Polo 配对协议（端口 6467）：
//  1. 基于 NWConnection 建立 mTLS 客户端双向认证连接；
//  2. 完成 PairingRequest -> Options -> Configuration 握手，触发电视展示 6 位配对码；
//  3. 基于服务端/客户端 RSA 公钥模数指数计算 SHA-256 Secret 校验并完成秘钥交换。
//

import Foundation
import Network
import Security

public enum AndroidTVTLSFactory {
    public static func makeTLSParameters(
        identity: SecIdentity,
        queue: DispatchQueue,
        onServerCertificate: @escaping (Data) -> Void
    ) -> NWParameters {
        let tlsOptions = NWProtocolTLS.Options()
        let secOptions = tlsOptions.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)
        if let secId = sec_identity_create(identity) {
            sec_protocol_options_set_local_identity(secOptions, secId)
        }
        sec_protocol_options_set_verify_block(secOptions, { (_, secTrust, completionHandler) in
            let trust = sec_trust_copy_ref(secTrust).takeRetainedValue()
            if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
               let leaf = chain.first {
                let der = SecCertificateCopyData(leaf) as Data
                onServerCertificate(der)
            }
            completionHandler(true)
        }, queue)
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 8
        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        params.includePeerToPeer = true
        return params
    }
}

public final class AndroidTVPairingSession {
    public let host: String
    public let pairingPort: UInt16
    public let clientName: String
    
    private let queue = DispatchQueue(label: "com.tanghulu.androidtv.pairing", qos: .userInitiated)
    private var connection: nw_connection_t?
    private var receiveBuffer = Data()
    private var clientCertDER: Data?
    private var serverCertDER: Data?
    private var isAwaitingPIN = false
    private var isCancelledOrFinished = false
    private var timeoutWorkItem: DispatchWorkItem?
    
    public var onRequirePIN: (() -> Void)?
    public var onComplete: ((Result<Data, Error>) -> Void)?
    
    public init(host: String, pairingPort: UInt16 = 6467, clientName: String = "糖葫芦遥控器") {
        self.host = host
        self.pairingPort = pairingPort
        self.clientName = clientName
    }
    
    public func start() {
        queue.async { [weak self] in
            self?.startInternal()
        }
    }
    
    public func cancel() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.finish(with: .failure(CancellationError()))
        }
    }
    
    public func submitPIN(_ pin: String) {
        queue.async { [weak self] in
            self?.handleSubmittedPIN(pin)
        }
    }
    
    private func startInternal() {
        guard !isCancelledOrFinished else { return }
        
        let identity: SecIdentity
        let certDER: Data
        do {
            let pair = try AndroidTVCertificateManager.shared.loadOrCreateClientIdentity()
            identity = pair.identity
            certDER = pair.certDER
            self.clientCertDER = certDER
        } catch {
            finish(with: .failure(error))
            return
        }
        
        let params = AndroidTVTLSFactory.makeTLSParameters(identity: identity, queue: queue) { [weak self] der in
            self?.serverCertDER = der
        }
        
        guard let nwPort = NWEndpoint.Port(rawValue: pairingPort) else {
            finish(with: .failure(AndroidTVPairingError.certificateGenerationFailed("无效配对端口 \(pairingPort)")))
            return
        }
        
        let endpoint = NWEndpoint.Host(host)
        let nwConn = NWConnection(host: endpoint, port: nwPort, using: params)
        
        nwConn.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state)
        }
        
        self.connection = nil
        // 使用 Swift NWConnection 包装
        self.startNWConnection(nwConn)
    }
    
    private var swiftConnection: NWConnection?
    
    private func startNWConnection(_ conn: NWConnection) {
        self.swiftConnection = conn
        conn.start(queue: queue)
        scheduleStepTimeout(seconds: 10.0, message: "配对握手超时（10秒）")
    }
    
    private func handleConnectionState(_ state: NWConnection.State) {
        guard !isCancelledOrFinished else { return }
        NSLog("[AndroidTV_Pairing] NWConnection state -> %@", "\(state)")
        switch state {
        case .ready:
            NSLog("[AndroidTV_Pairing] TLS ready on %@:%d, sending pairing_request", host, pairingPort)
            startReceiveLoop()
            sendPolo(.pairingRequest(serviceName: "atvremote", clientName: clientName))
        case .failed(let err):
            finish(with: .failure(err))
        case .cancelled:
            finish(with: .failure(CancellationError()))
        default:
            break
        }
    }
    
    private func startReceiveLoop() {
        guard let conn = swiftConnection, !isCancelledOrFinished else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, !self.isCancelledOrFinished else { return }
            if let data = data, !data.isEmpty {
                self.receiveBuffer.append(data)
                self.drainReceiveBuffer()
            }
            if let error = error {
                self.finish(with: .failure(error))
                return
            }
            if isComplete {
                self.finish(with: .failure(NSError(domain: "AndroidTVPairing", code: -2, userInfo: [NSLocalizedDescriptionKey: "Android TV 配对通道已关闭"])))
                return
            }
            self.startReceiveLoop()
        }
    }
    
    private func drainReceiveBuffer() {
        do {
            while let rawFrame = try ProtobufCodec.popLengthPrefixedFrame(from: &receiveBuffer) {
                let outer = try PoloOuterMessage.decode(from: rawFrame)
                handleOuterMessage(outer)
                if isCancelledOrFinished { break }
            }
        } catch {
            finish(with: .failure(error))
        }
    }
    
    private func handleOuterMessage(_ msg: PoloOuterMessage) {
        guard msg.status == .ok else {
            let reason: String
            switch msg.status {
            case .badSecret:
                reason = "配对码错误，请核对电视屏幕上显示的 6 位字符配对码。"
            case .badConfiguration:
                reason = "电视拒绝了当前配对参数配置。"
            default:
                reason = "电视返回配对异常状态码 (\(msg.statusRaw))。"
            }
            finish(with: .failure(NSError(domain: "AndroidTVPairing", code: Int(msg.statusRaw), userInfo: [NSLocalizedDescriptionKey: reason])))
            return
        }
        
        switch msg.payload {
        case .pairingRequestAck:
            scheduleStepTimeout(seconds: 10.0, message: "等待配置协商超时")
            let hexEnc = PoloEncoding(type: .hexadecimal, symbolLength: 6)
            sendPolo(.options(PoloOptions(inputEncodings: [hexEnc], preferredRole: .input)))
            
        case .options:
            scheduleStepTimeout(seconds: 10.0, message: "等待配置确认超时")
            let hexEnc = PoloEncoding(type: .hexadecimal, symbolLength: 6)
            sendPolo(.configuration(PoloConfiguration(encoding: hexEnc, clientRole: .input)))
            
        case .configurationAck:
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
            isAwaitingPIN = true
            NSLog("[AndroidTV_Pairing] Configuration ACK received; awaiting 6-char hex PIN from user")
            DispatchQueue.main.async { [weak self] in
                self?.onRequirePIN?()
            }
            
        case .secretAck:
            NSLog("[AndroidTV_Pairing] Secret ACK received; Android TV pairing succeeded!")
            let serverDER = self.serverCertDER ?? Data()
            finish(with: .success(serverDER))
            
        default:
            break
        }
    }
    
    private func handleSubmittedPIN(_ rawPIN: String) {
        guard !isCancelledOrFinished else { return }
        let trimmed = rawPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            finish(with: .failure(CancellationError()))
            return
        }
        guard isAwaitingPIN else { return }
        guard let clientDER = clientCertDER else {
            finish(with: .failure(AndroidTVPairingError.certificateGenerationFailed("缺少客户端证书")))
            return
        }
        guard let serverDER = serverCertDER, !serverDER.isEmpty else {
            finish(with: .failure(AndroidTVPairingError.missingServerCertificate))
            return
        }
        
        do {
            let secret = try AndroidTVCertificateManager.computePairingSecret(
                clientCertDER: clientDER,
                serverCertDER: serverDER,
                pinCode: trimmed
            )
            scheduleStepTimeout(seconds: 10.0, message: "等待电视校验配对码超时")
            sendPolo(.secret(secret))
        } catch {
            NSLog("[AndroidTV_Pairing] Local PIN secret verification failed: %@", error.localizedDescription)
            finish(with: .failure(error))
        }
    }
    
    private func sendPolo(_ payload: PoloOuterMessage.Payload) {
        guard let conn = swiftConnection, !isCancelledOrFinished else { return }
        let msg = PoloOuterMessage(protocolVersion: 2, status: .ok, payload: payload)
        let framed = ProtobufCodec.wrapLengthPrefixed(msg.encode())
        conn.send(content: framed, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.finish(with: .failure(error))
            }
        })
    }
    
    private func scheduleStepTimeout(seconds: TimeInterval, message: String) {
        timeoutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.finish(with: .failure(NSError(domain: "AndroidTVPairing", code: -1001, userInfo: [NSLocalizedDescriptionKey: message])))
        }
        timeoutWorkItem = item
        queue.asyncAfter(deadline: .now() + seconds, execute: item)
    }
    
    private func finish(with result: Result<Data, Error>) {
        guard !isCancelledOrFinished else { return }
        isCancelledOrFinished = true
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        swiftConnection?.cancel()
        swiftConnection = nil
        
        let cb = onComplete
        onComplete = nil
        onRequirePIN = nil
        
        DispatchQueue.main.async {
            cb?(result)
        }
    }
}
