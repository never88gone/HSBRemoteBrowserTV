//
//  HSBTVOSConnectionManager.m
//  HSBWatchCompanion
//

#import "HSBTVOSConnectionManager.h"
#import "HSBTVOSKeychainStore.h"
#import "HSBTVOSMessageParser.h"
#import "HSBTVOSInboundDispatcher.h"
#import "HSBTVOSPairingCoordinator.h"
#import "HSBTVOSHeartbeatCoordinator.h"
#import "HSBTVOSTCPConnector.h"
#import <UIKit/UIKit.h>

@interface HSBTVOSConnectionManager () <HSBTVOSPairingCoordinatorDelegate, HSBTVOSHeartbeatCoordinatorDelegate, HSBTVOSTCPConnectorDelegate>

@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, strong, nullable) nw_connection_t connection;
@property (nonatomic, copy, nullable) NSString *deviceName;
@property (nonatomic, strong, nullable) nw_endpoint_t currentEndpoint;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) HSBTVOSPairingCoordinator *pairingCoordinator;
@property (nonatomic, strong) HSBTVOSHeartbeatCoordinator *heartbeatCoordinator;
@property (nonatomic, strong) HSBTVOSTCPConnector *tcpConnector;
@property (nonatomic, assign) NSUInteger connectionGeneration;
@property (nonatomic, assign) BOOL isAppInBackground;
@property (nonatomic, strong, nullable) NSDate *lastReceivedMessageDate;

@end

@implementation HSBTVOSConnectionManager

+ (instancetype)sharedManager {
    static HSBTVOSConnectionManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HSBTVOSConnectionManager alloc] init];
    });
    return instance;
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)pairedTVRecords {
    return [HSBTVOSKeychainStore pairedTVRecords];
}

- (BOOL)isReconnecting {
    return self.heartbeatCoordinator.isReconnecting;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.tanghulu.tvosconnection", DISPATCH_QUEUE_SERIAL);
        _pairingCoordinator = [[HSBTVOSPairingCoordinator alloc] init];
        _pairingCoordinator.delegate = self;
        _heartbeatCoordinator = [[HSBTVOSHeartbeatCoordinator alloc] initWithQueue:_queue];
        _heartbeatCoordinator.delegate = self;
        _tcpConnector = [[HSBTVOSTCPConnector alloc] init];
        _tcpConnector.delegate = self;
        _isConnected = NO;
        _isAppInBackground = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

#pragma mark - Lifecycle & Keepalive

- (void)handleAppDidEnterBackground {
    NSLog(@"[BonjourBridge] iPhone app entered background. Suspending active timers.");
    self.isAppInBackground = YES;
    [self.heartbeatCoordinator suspendAll];
}

- (void)handleAppDidBecomeActive {
    [self handleAppWillEnterForeground];
}

- (void)handleAppWillEnterForeground {
    self.isAppInBackground = NO;
    NSLog(@"[BonjourBridge] iPhone app will enter foreground. Checking TV connection state...");
    
    if (!self.isConnected || !self.connection) {
        NSLog(@"[BonjourBridge] Offline on foreground wake. Triggering immediate reconnect...");
        [self triggerImmediateReconnect];
        return;
    }
    
    NSLog(@"[BonjourBridge] Probing active connection health with ping...");
    [self sendPingProbe];
    [self.heartbeatCoordinator startHeartbeat];
}

- (void)triggerImmediateReconnect {
    [self.heartbeatCoordinator stopReconnect];
    [self.heartbeatCoordinator resetReconnectAttempts];
    [self performReconnectAttempt];
}

- (void)performReconnectAttempt {
    if (self.isAppInBackground || self.isConnected) {
        return;
    }
    
    NSLog(@"[BonjourBridge] Executing reconnect attempt #%lu...", (unsigned long)self.heartbeatCoordinator.reconnectAttemptCount);
    
    if (self.currentEndpoint && ([self.pairingCoordinator isPairingTokenActive] || self.pairingCoordinator.pairedTVRecord)) {
        [self connectToEndpoint:self.currentEndpoint deviceName:self.deviceName ?: @"Apple TV"];
        return;
    }
    
    BOOL didConnect = [self connectToLastPairedTV];
    if (!didConnect) {
        NSLog(@"[BonjourBridge] Auto-reconnect did not find valid TV record.");
    }
}

- (void)sendPingProbe {
    if (!self.connection || !self.isConnected || self.isAppInBackground) {
        return;
    }
    
    NSDictionary *pingPayload = @{
        HSBRemotePayloadKeyAction: @"ping",
        @"timestamp": @((long long)([[NSDate date] timeIntervalSince1970] * 1000))
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:pingPayload options:0 error:nil];
    if (!data || data.length == 0) return;
    
    __weak typeof(self) weakSelf = self;
    nw_connection_t curConnection = self.connection;
    NSUInteger curGen = self.connectionGeneration;
    
    nw_connection_send(curConnection, [HSBTVOSKeychainStore createDispatchData:data], NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t sendError) {
        if (sendError) {
            NSLog(@"[BonjourBridge] Ping probe error: %@. Connection interrupted.", sendError);
            if (weakSelf.connection == curConnection && weakSelf.connectionGeneration == curGen) {
                dispatch_async(weakSelf.queue, ^{
                    [weakSelf handleConnectionInterrupted];
                });
            }
        }
    });
}

- (void)handleConnectionInterrupted {
    if (self.connection) {
        nw_connection_cancel(self.connection);
        self.connection = nil;
    }
    self.isConnected = NO;
    self.pairingCoordinator.isAuthenticating = NO;
    [self.heartbeatCoordinator stopHeartbeat];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification 
                                                        object:self 
                                                      userInfo:@{HSBConnectionStateKeyState: @(nw_connection_state_failed),
                                                                 HSBConnectionStateKeyMessage: @"🔴 Link interrupted. Reconnecting..."}];
    
    if (!self.isAppInBackground) {
        [self.heartbeatCoordinator scheduleReconnectWithDelay:0.5];
    }
}

#pragma mark - HSBTVOSHeartbeatCoordinatorDelegate

- (void)heartbeatCoordinatorDidTriggerPing:(HSBTVOSHeartbeatCoordinator *)coordinator {
    [self sendPingProbe];
}

- (void)heartbeatCoordinatorDidTriggerReconnect:(HSBTVOSHeartbeatCoordinator *)coordinator {
    [self performReconnectAttempt];
}

#pragma mark - TCP Parameters & Connection

- (BOOL)connectToLastPairedTV {
    NSArray *records = [HSBTVOSKeychainStore pairedTVRecords];
    if (records.count == 0) {
        NSLog(@"[BonjourBridge] No paired TV records in Keychain to reconnect.");
        return NO;
    }
    NSDictionary *record = records.lastObject ?: records.firstObject;
    [self.pairingCoordinator clearPairingSession];
    self.pairingCoordinator.pairedTVRecord = record;
    NSString *host = record[@"host"];
    NSString *portStr = record[@"port"] ?: @"56789";
    NSString *name = record[@"name"] ?: @"Apple TV";
    if (host.length == 0) return NO;
    NSLog(@"[BonjourBridge] Auto-connecting to last paired TV: %@ (%@:%@)", name, host, portStr);
    nw_endpoint_t endpoint = nw_endpoint_create_host(host.UTF8String, portStr.UTF8String);
    [self connectToEndpoint:endpoint deviceName:name];
    return YES;
}

- (void)connectToEndpoint:(nw_endpoint_t)endpoint deviceName:(NSString *)deviceName {
    self.currentEndpoint = endpoint;
    self.deviceName = deviceName;

    if (self.isConnected && self.connection) {
        if (self.pairingCoordinator.pairingToken.length == 0) {
            NSLog(@"[BonjourBridge] Already securely connected to %@.", self.deviceName);
            return;
        } else {
            nw_connection_cancel(self.connection);
            self.connection = nil;
            self.isConnected = NO;
            self.pairingCoordinator.isAuthenticating = NO;
        }
    }

    if (!self.pairingCoordinator.pairingToken || self.pairingCoordinator.pairedTVRecord) {
        NSDictionary *record = self.pairingCoordinator.pairedTVRecord;
        if (!record) {
            const char *epHost = nw_endpoint_get_hostname(endpoint);
            NSString *targetHost = epHost ? [NSString stringWithUTF8String:epHost] : nil;
            record = [HSBTVOSKeychainStore findRecordMatchingHost:targetHost deviceName:deviceName];
        }
        if (record && record[@"name"]) {
            self.deviceName = record[@"name"];
        }
        self.pairingCoordinator.pairedTVRecord = record;
        if (!record || [HSBTVOSKeychainStore dataFromBase64URLString:record[@"key"] ?: @""].length != 32) {
            self.isConnected = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                                object:self
                                                              userInfo:@{HSBConnectionStateKeyState: @(-1),
                                                                         HSBConnectionStateKeyMessage: @"Scan the TV pairing QR code to connect securely."}];
            return;
        }
        self.pairingCoordinator.deviceID = record[@"deviceID"];
        self.pairingCoordinator.deviceKey = record[@"key"];
    }
    
    if (self.connection) {
        nw_connection_cancel(self.connection);
        self.connection = nil;
    }
    
    BOOL isPairingFlow = [self.pairingCoordinator isPairingTokenActive] && !self.pairingCoordinator.pairedTVRecord;
    NSString *keyString = isPairingFlow ? self.pairingCoordinator.pairingToken : self.pairingCoordinator.pairedTVRecord[@"key"];
    NSData *key = keyString ? [HSBTVOSKeychainStore dataFromBase64URLString:keyString] : nil;
    NSString *identity = isPairingFlow ? @"pairing" : self.pairingCoordinator.pairedTVRecord[@"deviceID"];
    nw_parameters_t parameters = [HSBTVOSTCPConnector createParametersWithKey:key identity:identity];
    
    self.connectionGeneration++;
    self.connection = [self.tcpConnector createAndStartConnectionToEndpoint:endpoint parameters:parameters queue:self.queue];
}

#pragma mark - HSBTVOSTCPConnectorDelegate

- (void)tcpConnector:(HSBTVOSTCPConnector *)connector didBecomeReadyWithConnection:(nw_connection_t)connection {
    if (self.connection != connection) return;
    NSLog(@"[BonjourBridge] TLS ready; authenticating the paired device.");
    self.pairingCoordinator.isAuthenticating = YES;
    [self.heartbeatCoordinator stopReconnect];
    [self startReceivingFromConnection:connection buffer:[NSMutableData data]];
    [self.pairingCoordinator sendRemoteHelloOnConnection:connection];
}

- (void)tcpConnector:(HSBTVOSTCPConnector *)connector didFailWithConnection:(nw_connection_t)connection error:(nullable nw_error_t)error {
    if (self.connection != connection) return;
    NSLog(@"[BonjourBridge] TVOS Connection failed: %@. Scheduling reconnect...", error);
    self.isConnected = NO;
    self.pairingCoordinator.isAuthenticating = NO;
    self.connection = nil;
    [self.heartbeatCoordinator stopHeartbeat];
    [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification 
                                                        object:self 
                                                      userInfo:@{HSBConnectionStateKeyState: @(nw_connection_state_failed), HSBConnectionStateKeyMessage: @"🔴 Disconnected. Reconnecting..."}];
    
    if (self.pairingCoordinator.pairingToken.length > 0 && ![self.pairingCoordinator isPairingTokenActive]) {
        [self.pairingCoordinator clearPairingSession];
        self.currentEndpoint = nil;
    }
    
    if (!self.isAppInBackground) {
        [self.heartbeatCoordinator scheduleReconnectWithDelay:0.0];
    }
}

- (void)tcpConnector:(HSBTVOSTCPConnector *)connector didCancelWithConnection:(nw_connection_t)connection {
    if (self.connection != connection) return;
    NSLog(@"[BonjourBridge] TVOS Connection cancelled.");
    self.isConnected = NO;
    self.pairingCoordinator.isAuthenticating = NO;
    [self.heartbeatCoordinator stopHeartbeat];
    [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification 
                                                        object:self 
                                                      userInfo:@{HSBConnectionStateKeyState: @(nw_connection_state_cancelled), HSBConnectionStateKeyMessage: @"⚪️ Disconnected"}];
}

- (void)connectToPairingURL:(NSURL *)pairingURL {
    if (self.connection) {
        nw_connection_cancel(self.connection);
        self.connection = nil;
    }
    self.isConnected = NO;
    [self.pairingCoordinator handlePairingURL:pairingURL];
}

#pragma mark - HSBTVOSPairingCoordinatorDelegate

- (void)pairingCoordinator:(HSBTVOSPairingCoordinator *)coordinator didRequestConnectEndpoint:(nw_endpoint_t)endpoint deviceName:(NSString *)deviceName {
    [self connectToEndpoint:endpoint deviceName:deviceName];
}

- (void)pairingCoordinator:(HSBTVOSPairingCoordinator *)coordinator didCompleteSecurePairingWithRecord:(NSDictionary<NSString *,NSString *> *)record endpoint:(nw_endpoint_t)endpoint {
    NSString *name = self.deviceName ?: record[@"name"] ?: @"Apple TV";
    NSUInteger generation = self.connectionGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), self.queue, ^{
        if (generation != weakSelf.connectionGeneration || !endpoint) return;
        [weakSelf connectToEndpoint:endpoint deviceName:name];
    });
}

- (void)pairingCoordinator:(HSBTVOSPairingCoordinator *)coordinator didFailWithError:(NSString *)errorMessage {
    self.isConnected = NO;
    self.currentEndpoint = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                        object:self
                                                      userInfo:@{HSBConnectionStateKeyState: @(-1),
                                                                 HSBConnectionStateKeyMessage: errorMessage}];
}

- (void)pairingCoordinator:(HSBTVOSPairingCoordinator *)coordinator didAuthenticateConnection:(nw_connection_t)connection message:(NSString *)message {
    if (self.connection != connection || self.isConnected) return;
    self.isConnected = YES;
    [self.heartbeatCoordinator resetReconnectAttempts];
    [self.heartbeatCoordinator stopReconnect];
    [self.heartbeatCoordinator startHeartbeat];
    [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                        object:self
                                                      userInfo:@{HSBConnectionStateKeyState: @(nw_connection_state_ready),
                                                                 HSBConnectionStateKeyMessage: message}];
}

- (void)disconnect {
    [self.heartbeatCoordinator suspendAll];
    self.currentEndpoint = nil;
    self.deviceName = nil;
    [self.pairingCoordinator clearPairingSession];
    if (self.connection) {
        nw_connection_cancel(self.connection);
        self.connection = nil;
    }
    self.isConnected = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                        object:self
                                                      userInfo:@{HSBConnectionStateKeyState: @(nw_connection_state_cancelled),
                                                                 HSBConnectionStateKeyMessage: @"⚪️ Disconnected"}];
}

#pragma mark - Send Operations

- (void)sendAction:(NSString *)action {
    [self sendAction:action withValue:nil];
}

- (void)sendAction:(NSString *)action withValue:(nullable id)value {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = action;
    if (value) {
        payload[HSBRemotePayloadKeyValue] = value;
    }
    [self sendPayload:payload];
}

- (void)sendSimulateAction:(HSBRemoteSimulateAction)action {
    [self sendSimulateAction:action withParams:nil];
}

- (void)sendSimulateAction:(HSBRemoteSimulateAction)action withParams:(nullable NSDictionary *)params {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = action ?: HSBRemoteSimulateActionUnknown;
    if (params) {
        [payload addEntriesFromDictionary:params];
    }
    [self sendPayload:payload];
}

- (void)sendPayload:(NSDictionary *)payload {
    if (!self.connection || !self.isConnected) {
        if (!self.isAppInBackground && !self.heartbeatCoordinator.isReconnecting) {
            NSLog(@"[BonjourBridge] Attempted to send payload while offline. Triggering immediate reconnect...");
            [self triggerImmediateReconnect];
        }
        return;
    }
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (data && data.length > 0) {
        __weak typeof(self) weakSelf = self;
        nw_connection_t curConn = self.connection;
        NSUInteger curGen = self.connectionGeneration;
        nw_connection_send(self.connection, [HSBTVOSKeychainStore createDispatchData:data], NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t sendError) {
            if (sendError) {
                NSLog(@"[BonjourBridge] sendPayload error: %@. Marking connection interrupted.", sendError);
                if (weakSelf.connection == curConn && weakSelf.connectionGeneration == curGen) {
                    dispatch_async(weakSelf.queue, ^{
                        [weakSelf handleConnectionInterrupted];
                    });
                }
            }
        });
    }
}

- (void)sendJSONConfig:(NSString *)jsonString {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionUpdateHomeJson;
    payload[HSBRemotePayloadKeyPayload] = jsonString;
    [self sendPayload:payload];
}

#pragma mark - Receive Stream

- (void)startReceivingFromConnection:(nw_connection_t)connection buffer:(NSMutableData *)receiveBuffer {
    if (!connection || self.connection != connection) return;
    
    __weak typeof(self) weakSelf = self;
    nw_connection_receive(connection, 1, 65536, ^(dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_error_t error) {
        if (content) {
            const void *buffer = NULL;
            size_t size = 0;
            dispatch_data_t contiguousContent = dispatch_data_create_map(content, &buffer, &size);
            if (contiguousContent && buffer && size > 0) {
                NSData *chunk = [NSData dataWithBytes:buffer length:size];
                if (chunk.length > HSBMaxIncomingJSONBytes ||
                    receiveBuffer.length > HSBMaxIncomingJSONBytes - chunk.length) {
                    NSLog(@"[BonjourBridge] Inbound JSON exceeded size limit; closing connection.");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (weakSelf.connection == connection) [weakSelf disconnect];
                    });
                    return;
                }
                [receiveBuffer appendData:chunk];
                for (NSData *messageData in [HSBTVOSMessageParser extractJSONMessagesFromBuffer:receiveBuffer]) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:messageData options:0 error:nil];
                    if (json && [json isKindOfClass:[NSDictionary class]]) {
                        NSString *action = json[HSBRemotePayloadKeyAction];
                        weakSelf.lastReceivedMessageDate = [NSDate date];
                        if ([action isEqualToString:@"pong"]) {
                            continue;
                        }
                        if ([action isEqualToString:@"remote_hello_ack"] ||
                            [action isEqualToString:@"remote_pairing_complete"] ||
                            [action isEqualToString:@"remote_pairing_failed"]) {
                            [weakSelf.pairingCoordinator handleSecureHandshakeResponse:json
                                                                       fromConnection:connection
                                                                      currentEndpoint:weakSelf.currentEndpoint];
                            continue;
                        }
                        if (!weakSelf.isConnected) continue;
                        
                        [HSBTVOSInboundDispatcher dispatchPayload:json fromManager:weakSelf];
                    }
                }
            }
        }
        
        if (!is_complete && !error && weakSelf.connection == connection) {
            [weakSelf startReceivingFromConnection:connection buffer:receiveBuffer];
        }
    });
}

@end
