//
//  HSBBrowserProtocolClient.swift
//  HSBWatchCompanion
//

import Foundation
import Network

public protocol HSBBrowserProtocolClientDelegate: AnyObject {
    func browserClient(_ client: HSBBrowserProtocolClient, didChangeState state: HSBConnectionState)
    func browserClient(_ client: HSBBrowserProtocolClient, didReceiveMessage message: [String: Any])
}

public final class HSBBrowserProtocolClient {
    public weak var delegate: HSBBrowserProtocolClientDelegate?
    
    private var connection: nw_connection_t?
    private let queue = DispatchQueue(label: "com.tanghulu.browser.client.queue", qos: .userInitiated)
    private let parser = HSBJSONMessageParser()
    private let reconnectionPolicy = HSBReconnectionPolicy()
    
    private(set) var currentEndpoint: nw_endpoint_t?
    private(set) var currentDeviceName: String?
    public private(set) var isConnected: Bool = false
    
    public init() {}
    
    public func connect(to endpoint: nw_endpoint_t, deviceName: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.disconnect()
            
            self.currentEndpoint = endpoint
            self.currentDeviceName = deviceName
            
            DispatchQueue.main.async {
                self.delegate?.browserClient(self, didChangeState: .connecting(deviceName: deviceName, mode: .screenOnly))
            }
            
            let tcpParams = nw_parameters_create()
            nw_parameters_set_include_peer_to_peer(tcpParams, true)
            
            let conn = nw_connection_create(endpoint, tcpParams)
            self.connection = conn
            nw_connection_set_queue(conn, self.queue)
            
            nw_connection_set_state_changed_handler(conn) { [weak self] state, error in
                guard let self = self else { return }
                self.handleConnectionStateChange(state, error: error)
            }
            
            nw_connection_start(conn)
        }
    }
    
    public func disconnect() {
        reconnectionPolicy.markManualDisconnect()
        if let conn = connection {
            nw_connection_cancel(conn)
            connection = nil
        }
        parser.reset()
        isConnected = false
        DispatchQueue.main.async {
            self.delegate?.browserClient(self, didChangeState: .disconnected)
        }
    }
    
    public func send(command: HSBScreenCommand, completion: ((Bool) -> Void)? = nil) {
        guard let data = command.toJSONData() else {
            completion?(false)
            return
        }
        send(rawJSONData: data, completion: completion)
    }
    
    public func send(rawJSONData: Data, completion: ((Bool) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self, let conn = self.connection, self.isConnected else {
                completion?(false)
                return
            }
            
            let dispatchData = rawJSONData.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> DispatchData in
                return DispatchData(bytes: buf)
            }
            
            nw_connection_send(
                conn,
                dispatchData as __DispatchData,
                HSBGetDefaultMessageContext(),
                true
            ) { error in
                completion?(error == nil)
            }
        }
    }
    
    private func handleConnectionStateChange(_ state: nw_connection_state_t, error: nw_error_t?) {
        if state == nw_connection_state_ready {
            isConnected = true
            reconnectionPolicy.notifyConnected()
            let deviceName = currentDeviceName ?? "Apple TV"
            DispatchQueue.main.async {
                self.delegate?.browserClient(self, didChangeState: .ready(deviceName: deviceName, mode: .screenOnly))
            }
            receiveLoop()
        } else if state == nw_connection_state_failed {
            isConnected = false
            let errDesc = error.map { "\($0)" } ?? "Connection failed"
            DispatchQueue.main.async {
                self.delegate?.browserClient(self, didChangeState: .failed(error: errDesc))
            }
            scheduleReconnectIfNeeded()
        } else if state == nw_connection_state_cancelled {
            isConnected = false
            DispatchQueue.main.async {
                self.delegate?.browserClient(self, didChangeState: .disconnected)
            }
        }
    }
    
    private func receiveLoop() {
        guard let conn = connection, isConnected else { return }
        
        nw_connection_receive(conn, 1, 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            
            if let content = content {
                let receivedData = Data(content as DispatchData)
                let completeMessages = self.parser.append(data: receivedData)
                
                for msgData in completeMessages {
                    if let json = try? JSONSerialization.jsonObject(with: msgData, options: []) as? [String: Any] {
                        DispatchQueue.main.async {
                            self.delegate?.browserClient(self, didReceiveMessage: json)
                        }
                    }
                }
            }
            
            if isComplete || error != nil {
                self.isConnected = false
                self.scheduleReconnectIfNeeded()
            } else {
                self.receiveLoop()
            }
        }
    }
    
    private func scheduleReconnectIfNeeded() {
        let scheduled = reconnectionPolicy.scheduleReconnectIfEligible { [weak self] _, _ in
            guard let self = self, let endpoint = self.currentEndpoint, let name = self.currentDeviceName else { return }
            self.connect(to: endpoint, deviceName: name)
        }
        if !scheduled {
            print("[BrowserClient] Auto reconnect not eligible or max attempts reached.")
        }
    }
}
