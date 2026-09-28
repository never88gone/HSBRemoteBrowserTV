//
//  HSBTVOSConnectionManager.m
//  HSBWatchCompanion
//

#import "HSBTVOSConnectionManager.h"
#import "HSBLocalLLMManager.h"
#import <UIKit/UIKit.h>
#import <Security/Security.h>

static NSString * const HSBRemotePairedTVKeychainService = @"com.nevergone.hsbtvremote.paired-tvs.v1";
static NSString * const HSBRemotePairedTVKeychainAccount = @"paired-devices";
static NSString * const HSBRemoteDeviceIDDefaultsKey = @"HSBRemote.DeviceIdentity.v1";

static dispatch_data_t HSBRemoteDispatchData(NSData *data) {
    NSData *stableData = [data copy];
    return dispatch_data_create(stableData.bytes, stableData.length, dispatch_get_main_queue(), ^{
        (void)stableData;
    });
}

static NSString *HSBRemoteBase64URLString(NSData *data) {
    NSString *value = [[data base64EncodedStringWithOptions:0]
        stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    value = [value stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
}

static NSData *HSBRemoteDataFromBase64URLString(NSString *value) {
    NSString *base64 = [[value stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
        stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSUInteger remainder = base64.length % 4;
    if (remainder > 0) base64 = [base64 stringByPaddingToLength:base64.length + (4 - remainder)
                                                    withString:@"=" startingAtIndex:0];
    return [[NSData alloc] initWithBase64EncodedString:base64 options:0];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *HSBRemotePairedTVRecords(void) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: HSBRemotePairedTVKeychainService,
        (__bridge id)kSecAttrAccount: HSBRemotePairedTVKeychainAccount,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess || !result) return @[];
    NSData *data = CFBridgingRelease(result);
    id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [decoded isKindOfClass:[NSArray class]] ? decoded : @[];
}

static BOOL HSBRemoteSavePairedTVRecords(NSArray<NSDictionary<NSString *, NSString *> *> *records) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:records options:0 error:nil];
    if (!data) return NO;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: HSBRemotePairedTVKeychainService,
        (__bridge id)kSecAttrAccount: HSBRemotePairedTVKeychainAccount
    };
    NSDictionary *attributes = @{
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    };
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *add = [query mutableCopy];
        [add addEntriesFromDictionary:attributes];
        status = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    }
    if (status != errSecSuccess) {
        NSLog(@"[BonjourBridge] Keychain could not save paired-TV credentials (OSStatus %d).", (int)status);
    }
    return status == errSecSuccess;
}

NSString * const HSBTVOSConnectionStateNotification = @"HSBTVOSConnectionStateNotification";
NSString * const HSBTVOSStateUpdatedNotification = @"HSBTVOSStateUpdatedNotification";
NSString * const HSBIPTVFavoritesUpdatedNotification = @"HSBIPTVFavoritesUpdatedNotification";
NSString * const HSBIPTVCatalogUpdatedNotification = @"HSBIPTVCatalogUpdatedNotification";
NSString * const HSBIPTVStateUpdatedNotification = @"HSBIPTVStateUpdatedNotification";
NSString * const HSBIPTVImportResultUpdatedNotification = @"HSBIPTVImportResultUpdatedNotification";
NSString * const HSBIPTVSourcesUpdatedNotification = @"HSBIPTVSourcesUpdatedNotification";
NSString * const HSBIPTVEPGBindingsUpdatedNotification = @"HSBIPTVEPGBindingsUpdatedNotification";
NSString * const HSBIPTVEPGCandidatesUpdatedNotification = @"HSBIPTVEPGCandidatesUpdatedNotification";
static NSUInteger const HSBMaxIncomingJSONBytes = 1024 * 1024;

// Network.framework 的 TCP receive 返回任意字节块，不对应 send 边界。
// 从持久缓冲区中提取一个或多个完整 JSON，兼容拆包和粘包。
static NSArray<NSData *> *HSBExtractJSONMessages(NSMutableData *buffer) {
    if (buffer.length == 0) return @[];

    const uint8_t *bytes = buffer.bytes;
    NSMutableArray<NSData *> *messages = [NSMutableArray array];
    NSUInteger start = NSNotFound;
    NSUInteger consumed = 0;
    NSInteger depth = 0;
    BOOL inString = NO;
    BOOL escaped = NO;

    for (NSUInteger i = 0; i < buffer.length; i++) {
        uint8_t byte = bytes[i];
        if (start == NSNotFound) {
            if (byte == '{' || byte == '[') {
                start = i;
                depth = 1;
                inString = NO;
                escaped = NO;
            } else {
                consumed = i + 1;
            }
            continue;
        }

        if (inString) {
            if (escaped) {
                escaped = NO;
            } else if (byte == '\\') {
                escaped = YES;
            } else if (byte == '"') {
                inString = NO;
            }
            continue;
        }

        if (byte == '"') {
            inString = YES;
        } else if (byte == '{' || byte == '[') {
            depth++;
        } else if (byte == '}' || byte == ']') {
            depth--;
            if (depth == 0) {
                [messages addObject:[buffer subdataWithRange:NSMakeRange(start, i - start + 1)]];
                consumed = i + 1;
                start = NSNotFound;
            }
        }
    }

    if (consumed > 0) {
        [buffer replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
    }
    return messages;
}

@interface HSBTVOSConnectionManager ()

@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, strong, nullable) nw_connection_t connection;
@property (nonatomic, copy, nullable) NSString *deviceName;
@property (nonatomic, strong, nullable) nw_endpoint_t currentEndpoint;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, copy, nullable) NSString *pairingToken;
@property (nonatomic, copy, nullable) NSString *pairingTVID;
@property (nonatomic, copy, nullable) NSString *pairingHost;
@property (nonatomic, copy, nullable) NSString *pairingName;
@property (nonatomic, strong, nullable) NSDate *pairingExpirationDate;
@property (nonatomic, copy, nullable) NSString *deviceID;
@property (nonatomic, copy, nullable) NSString *deviceKey;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *pairedTVRecord;
@property (nonatomic, assign) BOOL isAuthenticating;
@property (nonatomic, assign) NSUInteger connectionGeneration;

- (void)startReceivingFromConnection:(nw_connection_t)connection buffer:(NSMutableData *)receiveBuffer;

@end

@implementation HSBTVOSConnectionManager

HSBRemoteSimulateAction const HSBRemoteSimulateActionUnknown = @"unknown";
HSBRemoteSimulateAction const HSBRemoteSimulateActionUp = @"up";
HSBRemoteSimulateAction const HSBRemoteSimulateActionDown = @"down";
HSBRemoteSimulateAction const HSBRemoteSimulateActionLeft = @"left";
HSBRemoteSimulateAction const HSBRemoteSimulateActionRight = @"right";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSelect = @"select";
HSBRemoteSimulateAction const HSBRemoteSimulateActionMenu = @"menu";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPlay = @"play";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPause = @"pause";
HSBRemoteSimulateAction const HSBRemoteSimulateActionStop = @"stop";
HSBRemoteSimulateAction const HSBRemoteSimulateActionOpenPlayer = @"open_player";
HSBRemoteSimulateAction const HSBRemoteSimulateActionClosePlayer = @"close_player";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekRelative = @"seek_relative";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekPercent = @"seek_percent";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSetRate = @"set_rate";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekForward = @"seek_forward";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekBackward = @"seek_backward";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekAbsolute = @"player_seek";
HSBRemoteSimulateAction const HSBRemoteSimulateActionToggleSubtitle = @"player_toggle_subtitle";
HSBRemoteSimulateAction const HSBRemoteSimulateActionVolumeUp = @"volume_up";
HSBRemoteSimulateAction const HSBRemoteSimulateActionVolumeDown = @"volume_down";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSetVolume = @"set_volume";
HSBRemoteSimulateAction const HSBRemoteSimulateActionToggleMute = @"toggle_mute";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSwitchAudioTrack = @"switch_audio_track";
HSBRemoteSimulateAction const HSBRemoteSimulateActionOpenUrl = @"open_url";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPageBack = @"page_back";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPageForward = @"page_forward";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPageReload = @"page_reload";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPageHome = @"page_home";
HSBRemoteSimulateAction const HSBRemoteSimulateActionUpdateHomeJson = @"update_home_json";
HSBRemoteSimulateAction const HSBRemoteSimulateActionExecuteJS = @"execute_js";
HSBRemoteSimulateAction const HSBRemoteSimulateActionPdfDraw = @"pdf_draw";
HSBRemoteSimulateAction const HSBRemoteSimulateActionMacTap = @"mac_tap";
HSBRemoteSimulateAction const HSBRemoteSimulateActionMacPan = @"mac_pan";
HSBRemoteSimulateAction const HSBRemoteSimulateActionMacScroll = @"mac_scroll";
HSBRemoteSimulateAction const HSBRemoteSimulateActionMacDrag = @"mac_drag";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVGetFavorites = @"get_favorites";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVPlayChannel = @"play_channel";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVAddFavorite = @"add_favorite";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVDeleteFavorite = @"delete_favorite";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVEpg = @"iptv_epg";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVChannels = @"iptv_channels";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVRefresh = @"iptv_refresh";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVImportSource = @"iptv_import_source";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVImportEPG = @"iptv_import_epg";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVFileChunk = @"iptv_file_chunk";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVGetSources = @"iptv_get_sources";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVDeleteSource = @"iptv_delete_source";
HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVRefreshSource = @"iptv_refresh_source";
HSBRemoteSimulateAction const HSBRemoteSimulateActionChannelUp = @"channel_up";
HSBRemoteSimulateAction const HSBRemoteSimulateActionChannelDown = @"channel_down";
HSBRemoteSimulateAction const HSBRemoteSimulateActionDigit = @"digit";
HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslate = @"translate";
HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslateBlocks = @"translate_blocks";
HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslationResult = @"translation_result";
HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslationBlocksResult = @"translation_blocks_result";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSyncProgress = @"sync_progress";
HSBRemoteSimulateAction const HSBRemoteSimulateActionSyncFavorites = @"sync_favorites";

NSString * const HSBRemotePayloadKeyAction = @"action";
NSString * const HSBRemotePayloadKeyValue = @"value";
NSString * const HSBRemotePayloadKeySeconds = @"seconds";
NSString * const HSBRemotePayloadKeyVolume = @"volume";
NSString * const HSBRemotePayloadKeyMuted = @"muted";
NSString * const HSBRemotePayloadKeyDigit = @"digit";
NSString * const HSBRemotePayloadKeyTrackIndex = @"trackIndex";
NSString * const HSBRemotePayloadKeyDx = @"dx";
NSString * const HSBRemotePayloadKeyDy = @"dy";
NSString * const HSBRemotePayloadKeyMode = @"mode";
NSString * const HSBRemotePayloadKeyState = @"state";
NSString * const HSBRemotePayloadKeyUrl = @"url";
NSString * const HSBRemotePayloadKeyScript = @"script";
NSString * const HSBRemotePayloadKeyType = @"type";
NSString * const HSBRemotePayloadKeyX = @"x";
NSString * const HSBRemotePayloadKeyY = @"y";
NSString * const HSBRemotePayloadKeyColor = @"color";
NSString * const HSBRemotePayloadKeyWidth = @"width";
NSString * const HSBRemotePayloadKeyPayload = @"payload";
NSString * const HSBRemotePayloadKeyChannel = @"channel";
NSString * const HSBRemotePayloadKeyId = @"id";
NSString * const HSBRemotePayloadKeyIndex = @"index";
NSString * const HSBRemotePayloadKeyTimestamp = @"timestamp";
NSString * const HSBRemotePayloadKeyRequestId = @"requestId";
NSString * const HSBRemotePayloadKeyResult = @"result";
NSString * const HSBRemotePayloadKeyBlocks = @"blocks";
NSString * const HSBRemotePayloadKeyTranslationMap = @"translationMap";
NSString * const HSBRemotePayloadKeyChannels = @"channels";
NSString * const HSBRemotePayloadKeyCurrentTime = @"currentTime";
NSString * const HSBRemotePayloadKeyDuration = @"duration";
NSString * const HSBRemotePayloadKeyHidden = @"hidden";
NSString * const HSBRemotePayloadKeyPlaybackState = @"playbackState";
NSString * const HSBRemotePayloadKeyTitle = @"title";
NSString * const HSBRemotePayloadKeyContent = @"content";
NSString * const HSBRemotePayloadKeyCode = @"code";
NSString * const HSBRemotePayloadKeyMessage = @"message";
NSString * const HSBRemotePayloadKeyError = @"error";
NSString * const HSBRemotePayloadKeyText = @"text";
NSString * const HSBRemotePayloadKeySourceLanguage = @"sourceLanguage";
NSString * const HSBRemotePayloadKeyTargetLanguage = @"targetLanguage";
NSString * const HSBRemotePayloadKeyRemoteAction = @"remoteAction";
NSString * const HSBRemotePayloadKeyPressType = @"pressType";
NSString * const HSBRemotePayloadKeyName = @"name";
NSString * const HSBRemotePayloadKeyStream = @"stream";
NSString * const HSBRemotePayloadKeyLogo = @"logo";
NSString * const HSBRemotePayloadKeyGroup = @"group";

// -- PDF & Drawing Constants ---------------------------------------------
NSString * const HSBRemoteDrawTypeClear = @"clear";
NSString * const HSBRemoteDrawTypeUndo = @"undo";
NSString * const HSBRemoteDrawTypeEraser = @"eraser";
NSString * const HSBRemoteDrawTypeBegan = @"began";
NSString * const HSBRemoteDrawTypeMoved = @"moved";
NSString * const HSBRemoteDrawTypeChanged = @"changed";
NSString * const HSBRemoteDrawTypeEnded = @"ended";
NSString * const HSBRemoteDrawColorRed = @"#FF0000";
NSString * const HSBRemoteDrawColorBlue = @"blue";
NSString * const HSBRemoteDrawColorGreen = @"green";
NSString * const HSBRemoteDrawColorYellow = @"yellow";
NSString * const HSBRemoteDrawColorWhite = @"white";
NSString * const HSBRemoteDrawColorBlack = @"black";

// -- Notification UserInfo Keys ------------------------------------------
NSString * const HSBConnectionStateKeyMessage = @"message";
NSString * const HSBConnectionStateKeyState = @"state";

+ (instancetype)sharedManager {
    static HSBTVOSConnectionManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HSBTVOSConnectionManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.tanghulu.tvosconnection", DISPATCH_QUEUE_SERIAL);
        _isConnected = NO;
    }
    return self;
}

- (nw_parameters_t)createTCPParameters {
    NSString *keyString = self.pairingToken ?: self.pairedTVRecord[@"key"];
    NSData *key = keyString ? HSBRemoteDataFromBase64URLString(keyString) : nil;
    NSString *identity = self.pairingToken ? @"pairing" : self.pairedTVRecord[@"deviceID"];
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(^(nw_protocol_options_t tlsOptions) {
        sec_protocol_options_t securityOptions = nw_tls_copy_sec_protocol_options(tlsOptions);
        sec_protocol_options_set_min_tls_protocol_version(securityOptions, tls_protocol_version_TLSv12);
        if (key.length == 32 && identity.length > 0) {
            sec_protocol_options_add_pre_shared_key(securityOptions,
                HSBRemoteDispatchData(key), HSBRemoteDispatchData([identity dataUsingEncoding:NSUTF8StringEncoding]));
        }
    }, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_include_peer_to_peer(parameters, true);
    return parameters;
}

- (void)connectToEndpoint:(nw_endpoint_t)endpoint deviceName:(NSString *)deviceName {
    self.currentEndpoint = endpoint;
    self.deviceName = deviceName;

    if (!self.pairingToken) {
        NSDictionary *record = nil;
        for (NSDictionary *candidate in HSBRemotePairedTVRecords()) {
            if ([candidate[@"name"] isEqualToString:deviceName]) { record = candidate; break; }
        }
        self.pairedTVRecord = record;
        if (!record || HSBRemoteDataFromBase64URLString(record[@"key"] ?: @"").length != 32) {
            self.isConnected = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                                object:self
                                                              userInfo:@{HSBConnectionStateKeyState: @(-1),
                                                                         HSBConnectionStateKeyMessage: @"Scan the TV pairing QR code to connect securely."}];
            return;
        }
        self.deviceID = record[@"deviceID"];
        self.deviceKey = record[@"key"];
    }
    
    if (self.connection) {
        nw_connection_cancel(self.connection);
        self.connection = nil;
    }
    
    nw_parameters_t parameters = [self createTCPParameters];
    nw_connection_t connection = nw_connection_create(endpoint, parameters);
    self.connection = connection;
    NSUInteger generation = ++self.connectionGeneration;
    
    __weak typeof(self) weakSelf = self;
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        // 被替换或主动断开的旧连接仍可能回调 cancelled/failed，不能让它
        // 覆盖当前新连接的在线状态，也不能触发额外重连。
        if (weakSelf.connection != connection || generation != weakSelf.connectionGeneration) return;

        switch (state) {
            case nw_connection_state_ready: {
                NSLog(@"[BonjourBridge] TLS ready; authenticating the paired device.");
                weakSelf.isAuthenticating = YES;
                [weakSelf startReceivingFromConnection:connection buffer:[NSMutableData data]];
                [weakSelf sendRemoteHelloOnConnection:connection];
                break;
            }
            case nw_connection_state_failed: {
                NSLog(@"[BonjourBridge] TVOS Connection failed: %@. Reconnecting in 2s...", error);
                weakSelf.isConnected = NO;
                weakSelf.isAuthenticating = NO;
                weakSelf.connection = nil;
                [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification 
                                                                    object:weakSelf 
                                                                  userInfo:@{HSBConnectionStateKeyState: @(state), HSBConnectionStateKeyMessage: @"🔴 Error. Reconnecting..."}];
                // Auto-reconnect after 2 seconds
                BOOL pairingIsCurrent = weakSelf.pairingToken.length > 0 &&
                    weakSelf.pairingExpirationDate.timeIntervalSinceNow > 0;
                if (weakSelf.pairingToken.length > 0 && !pairingIsCurrent) {
                    weakSelf.pairingToken = nil;
                    weakSelf.pairingExpirationDate = nil;
                    weakSelf.pairingTVID = nil;
                    weakSelf.pairingHost = nil;
                    weakSelf.pairingName = nil;
                    weakSelf.deviceKey = nil;
                    weakSelf.currentEndpoint = nil;
                } else if (weakSelf.currentEndpoint && (pairingIsCurrent || weakSelf.pairedTVRecord)) {
                    nw_endpoint_t retryEndpoint = weakSelf.currentEndpoint;
                    NSString *retryName = weakSelf.deviceName;
                    NSUInteger failedGeneration = generation;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), weakSelf.queue, ^{
                        if (weakSelf.connectionGeneration != failedGeneration || weakSelf.currentEndpoint != retryEndpoint) return;
                        [weakSelf connectToEndpoint:retryEndpoint deviceName:retryName];
                    });
                }
                break;
            }
            case nw_connection_state_cancelled: {
                NSLog(@"[BonjourBridge] TVOS Connection cancelled.");
                weakSelf.isConnected = NO;
                weakSelf.isAuthenticating = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification 
                                                                    object:weakSelf 
                                                                  userInfo:@{HSBConnectionStateKeyState: @(state), HSBConnectionStateKeyMessage: @"⚪️ Disconnected"}];
                break;
            }
            default:
                break;
        }
    });
    
    nw_connection_set_queue(connection, self.queue);
    nw_connection_start(connection);
}

- (void)sendRemoteHelloOnConnection:(nw_connection_t)connection {
    if (!connection || !self.deviceID || !self.deviceKey) return;
    NSMutableDictionary *hello = [@{
        HSBRemotePayloadKeyAction: @"remote_hello",
        @"deviceID": self.deviceID,
        @"deviceName": UIDevice.currentDevice.name ?: @"iPhone",
        @"deviceKey": self.deviceKey,
        @"protocolVersion": @1,
        @"capabilities": @[@"remote-control", @"iptv", @"epg", @"playback"]
    } mutableCopy];
    if (self.pairingToken.length > 0) hello[@"pairingToken"] = self.pairingToken;
    NSData *data = [NSJSONSerialization dataWithJSONObject:hello options:0 error:nil];
    if (!data) return;
    nw_connection_send(connection, HSBRemoteDispatchData(data), NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
        if (error) NSLog(@"[BonjourBridge] TLS device hello failed: %@", error);
    });
}

- (void)postAuthenticatedConnectionStateForConnection:(nw_connection_t)connection message:(NSString *)message {
    if (self.connection != connection || self.isConnected) return;
    self.isAuthenticating = NO;
    self.isConnected = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                        object:self
                                                      userInfo:@{HSBConnectionStateKeyState: @(nw_connection_state_ready),
                                                                 HSBConnectionStateKeyMessage: message}];
}

- (void)connectToPairingURL:(NSURL *)pairingURL {
    NSURLComponents *components = [NSURLComponents componentsWithURL:pairingURL resolvingAgainstBaseURL:NO];
    if (![components.scheme isEqualToString:@"hsbremote"] ||
        ![components.host isEqualToString:@"pair"]) return;
    NSMutableDictionary<NSString *, NSString *> *values = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in components.queryItems) if (item.name && item.value) values[item.name] = item.value;
    NSString *tvID = values[@"tv"], *name = values[@"name"], *host = values[@"host"], *token = values[@"token"];
    NSInteger port = values[@"port"].integerValue;
    NSTimeInterval expiry = values[@"expires"].doubleValue;
    if (tvID.length == 0 || name.length == 0 || host.length == 0 || port < 1024 || port > 65535 ||
        HSBRemoteDataFromBase64URLString(token ?: @"").length != 32 || expiry <= NSDate.date.timeIntervalSince1970 ||
        expiry > NSDate.date.timeIntervalSince1970 + 180.0) return;

    NSMutableData *randomKey = [NSMutableData dataWithLength:32];
    if (SecRandomCopyBytes(kSecRandomDefault, randomKey.length, randomKey.mutableBytes) != errSecSuccess) return;
    NSString *deviceID = [[NSUserDefaults standardUserDefaults] stringForKey:HSBRemoteDeviceIDDefaultsKey];
    if (deviceID.length == 0) {
        deviceID = NSUUID.UUID.UUIDString;
        [[NSUserDefaults standardUserDefaults] setObject:deviceID forKey:HSBRemoteDeviceIDDefaultsKey];
    }
    self.pairingTVID = tvID;
    self.pairingName = name;
    self.pairingHost = host;
    self.pairingToken = token;
    self.pairingExpirationDate = [NSDate dateWithTimeIntervalSince1970:expiry];
    self.deviceID = deviceID;
    self.deviceKey = HSBRemoteBase64URLString(randomKey);
    self.pairedTVRecord = nil;
    nw_endpoint_t endpoint = nw_endpoint_create_host(host.UTF8String, [@(port) stringValue].UTF8String);
    [self connectToEndpoint:endpoint deviceName:name];
}

- (void)completeSecurePairingAndReconnect {
    NSDictionary *record = @{
        @"tvID": self.pairingTVID ?: @"",
        @"name": self.pairingName ?: self.deviceName ?: @"Apple TV",
        @"host": self.pairingHost ?: @"",
        @"port": @"56789",
        @"deviceID": self.deviceID ?: @"",
        @"key": self.deviceKey ?: @""
    };
    NSMutableArray *records = [HSBRemotePairedTVRecords() mutableCopy];
    NSIndexSet *existing = [records indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) {
        return [item[@"tvID"] isEqualToString:record[@"tvID"]];
    }];
    [records removeObjectsAtIndexes:existing];
    [records addObject:record];
    if (!HSBRemoteSavePairedTVRecords(records)) {
        NSLog(@"[BonjourBridge] Could not save paired-TV key in Keychain.");
        self.pairingToken = nil;
        self.pairingExpirationDate = nil;
        self.pairingTVID = nil;
        self.pairingHost = nil;
        self.pairingName = nil;
        self.isAuthenticating = NO;
        self.isConnected = NO;
        self.currentEndpoint = nil;
        if (self.connection) {
            nw_connection_cancel(self.connection);
            self.connection = nil;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                            object:self
                                                          userInfo:@{HSBConnectionStateKeyState: @(-1),
                                                                     HSBConnectionStateKeyMessage: @"Could not save secure pairing. Scan the TV code again."}];
        return;
    }
    self.pairedTVRecord = record;
    self.pairingToken = nil;
    self.pairingExpirationDate = nil;
    self.isAuthenticating = NO;
    nw_endpoint_t endpoint = self.currentEndpoint;
    NSString *name = self.deviceName ?: self.pairingName ?: @"Apple TV";
    NSUInteger generation = self.connectionGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), self.queue, ^{
        if (generation != self.connectionGeneration || !endpoint) return;
        [self connectToEndpoint:endpoint deviceName:name];
    });
}

- (void)handleSecureHandshakeResponse:(NSDictionary *)json fromConnection:(nw_connection_t)connection {
    if (self.connection != connection) return;
    NSString *action = [json[HSBRemotePayloadKeyAction] isKindOfClass:[NSString class]] ? json[HSBRemotePayloadKeyAction] : @"";
    if (([action isEqualToString:@"remote_hello_ack"] || [action isEqualToString:@"remote_pairing_complete"]) &&
        [json[@"protocolVersion"] integerValue] != 1) {
        NSLog(@"[BonjourBridge] TV remote protocol version is unsupported.");
        nw_connection_cancel(connection);
        self.isAuthenticating = NO;
        self.isConnected = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                            object:self
                                                          userInfo:@{HSBConnectionStateKeyState: @(-1),
                                                                     HSBConnectionStateKeyMessage: @"Update the TV app to connect securely."}];
        return;
    }
    if ([action isEqualToString:@"remote_hello_ack"] || [action isEqualToString:@"remote_pairing_complete"]) {
        NSString *expectedTVID = self.pairingTVID ?: self.pairedTVRecord[@"tvID"];
        NSString *actualTVID = [json[@"tvID"] isKindOfClass:[NSString class]] ? json[@"tvID"] : @"";
        NSArray *capabilities = [json[@"capabilities"] isKindOfClass:[NSArray class]] ? json[@"capabilities"] : @[];
        NSSet *negotiated = [NSSet setWithArray:capabilities];
        NSMutableSet *missingCapabilities = [NSMutableSet setWithArray:@[@"remote-control", @"iptv", @"epg", @"playback"]];
        [missingCapabilities minusSet:negotiated];
        if (expectedTVID.length == 0 || ![expectedTVID isEqualToString:actualTVID] || missingCapabilities.count > 0) {
            NSLog(@"[BonjourBridge] TV identity or iPTV capabilities do not match the paired remote.");
            nw_connection_cancel(connection);
            self.isAuthenticating = NO;
            self.isConnected = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                                object:self
                                                              userInfo:@{HSBConnectionStateKeyState: @(-1),
                                                                         HSBConnectionStateKeyMessage: @"Update the TV app to enable secure iPTV control."}];
            return;
        }
    }
    if ([action isEqualToString:@"remote_hello_ack"]) {
        [self postAuthenticatedConnectionStateForConnection:connection message:@"🟢 Securely connected to TV"];
    } else if ([action isEqualToString:@"remote_pairing_complete"]) {
        [self completeSecurePairingAndReconnect];
    } else if ([action isEqualToString:@"remote_pairing_failed"]) {
        self.isAuthenticating = NO;
        self.isConnected = NO;
        self.pairingToken = nil;
        self.pairingExpirationDate = nil;
        self.pairingTVID = nil;
        self.pairingHost = nil;
        self.pairingName = nil;
        self.currentEndpoint = nil;
        nw_connection_cancel(connection);
        [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification
                                                            object:self
                                                          userInfo:@{HSBConnectionStateKeyState: @(-1),
                                                                     HSBConnectionStateKeyMessage: @"Pairing expired. Scan the TV QR code again."}];
    }
}

- (void)disconnect {
    self.currentEndpoint = nil;
    self.deviceName = nil;
    self.pairingToken = nil;
    self.pairingExpirationDate = nil;
    self.pairingTVID = nil;
    self.pairingHost = nil;
    self.pairingName = nil;
    self.isAuthenticating = NO;
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
        return;
    }
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (data && data.length > 0) {
        dispatch_data_t dispatchData = dispatch_data_create(data.bytes, data.length, dispatch_get_main_queue(), ^{ [data self]; });
        nw_connection_send(self.connection, dispatchData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
            if (error) {
                NSLog(@"[BonjourBridge] sendPayload error: %@", error);
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
                for (NSData *messageData in HSBExtractJSONMessages(receiveBuffer)) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:messageData options:0 error:nil];
                    if (json && [json isKindOfClass:[NSDictionary class]]) {
                    NSString *action = json[HSBRemotePayloadKeyAction];
                    if ([action isEqualToString:@"remote_hello_ack"] ||
                        [action isEqualToString:@"remote_pairing_complete"] ||
                        [action isEqualToString:@"remote_pairing_failed"]) {
                        [weakSelf handleSecureHandshakeResponse:json fromConnection:connection];
                        continue;
                    }
                    // Ignore all TV state and command responses until the TLS PSK
                    // has been bound to a Keychain device record by the TV.
                    if (!weakSelf.isConnected) continue;
                    if ([action isEqualToString:HSBRemoteSimulateActionSyncProgress]) {
                        NSNumber *currentTime = json[HSBRemotePayloadKeyCurrentTime];
                        NSNumber *duration = json[HSBRemotePayloadKeyDuration];
                        NSNumber *hiddenObj = json[HSBRemotePayloadKeyHidden];
                        NSNumber *playbackState = json[HSBRemotePayloadKeyPlaybackState];
                        NSNumber *volume = json[HSBRemotePayloadKeyVolume];
                        NSNumber *muted = json[HSBRemotePayloadKeyMuted];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSStateUpdatedNotification 
                                                                                object:weakSelf 
                                                                              userInfo:@{HSBRemotePayloadKeyCurrentTime: currentTime ?: @(0), 
                                                                                         HSBRemotePayloadKeyDuration: duration ?: @(0), 
                                                                                         HSBRemotePayloadKeyHidden: hiddenObj ?: @(NO),
                                                                                         HSBRemotePayloadKeyPlaybackState: playbackState ?: @(NO),
                                                                                         HSBRemotePayloadKeyVolume: volume ?: @(1.0),
                                                                                         HSBRemotePayloadKeyMuted: muted ?: @(NO)}];
                        });
                    } else if ([action isEqualToString:HSBRemoteSimulateActionSyncFavorites]) {
                        NSArray *favorites = json[HSBRemotePayloadKeyChannels];
                        if (favorites && [favorites isKindOfClass:[NSArray class]]) {
                            [[NSUserDefaults standardUserDefaults] setObject:favorites forKey:@"HSBIPTVFavorites"];
                            [[NSUserDefaults standardUserDefaults] synchronize];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:HSBIPTVFavoritesUpdatedNotification 
                                                                                    object:weakSelf 
                                                                                  userInfo:@{HSBRemotePayloadKeyChannels: favorites}];
                            });
                        }
                    } else if ([action isEqualToString:@"iptv_catalog"] &&
                               [json[HSBRemotePayloadKeyChannels] isKindOfClass:[NSArray class]]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:HSBIPTVCatalogUpdatedNotification
                                                                                object:weakSelf
                                                                              userInfo:json];
                        });
                    } else if ([action isEqualToString:@"iptv_state"]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:HSBIPTVStateUpdatedNotification
                                                                                object:weakSelf
                                                                              userInfo:json];
                        });
                    } else if ([action isEqualToString:@"iptv_import_result"]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:HSBIPTVImportResultUpdatedNotification
                                                                                object:weakSelf
                                                                              userInfo:json];
                        });
                    } else if ([action isEqualToString:@"iptv_sources"] &&
                               [json[HSBRemotePayloadKeyChannels] isKindOfClass:[NSArray class]]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:HSBIPTVSourcesUpdatedNotification
                                                                                object:weakSelf
                                                                              userInfo:json];
                        });
                    } else if ([action isEqualToString:@"iptv_epg_bindings"]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:HSBIPTVEPGBindingsUpdatedNotification
                                                                                object:weakSelf
                                                                              userInfo:json];
                        });
                    } else if ([action isEqualToString:@"iptv_epg_candidates"]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:HSBIPTVEPGCandidatesUpdatedNotification
                                                                                object:weakSelf
                                                                              userInfo:json];
                        });
                    } else if ([action isEqualToString:HSBRemoteSimulateActionTranslate]) {
                        NSString *requestId = json[HSBRemotePayloadKeyRequestId];
                        NSString *text = json[HSBRemotePayloadKeyText];
                        NSString *sourceLanguage = json[HSBRemotePayloadKeySourceLanguage];
                        NSString *targetLanguage = json[HSBRemotePayloadKeyTargetLanguage];
                        if (requestId && text.length > 0) {
                            NSString *systemPrompt = [HSBLocalLLMManager translationSystemPromptWithSource:sourceLanguage target:targetLanguage];
                            [[HSBLocalLLMManager shared] processMessage:text systemPrompt:systemPrompt type:1 completion:^(NSString * _Nullable response, BOOL isFinished) {
                                if (isFinished) {
                                    [weakSelf sendPayload:@{
                                        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionTranslationResult,
                                        HSBRemotePayloadKeyRequestId: requestId,
                                        HSBRemotePayloadKeyResult: response ?: @""
                                    }];
                                }
                            }];
                        }
                    } else if ([action isEqualToString:HSBRemoteSimulateActionTranslateBlocks]) {
                        NSString *requestId = json[HSBRemotePayloadKeyRequestId];
                        NSArray *blocks = json[HSBRemotePayloadKeyBlocks];
                        NSString *sourceLanguage = json[HSBRemotePayloadKeySourceLanguage];
                        NSString *targetLanguage = json[HSBRemotePayloadKeyTargetLanguage];
                        if (requestId && blocks.count > 0) {
                            NSMutableDictionary *translationMap = [NSMutableDictionary dictionary];
                            dispatch_group_t group = dispatch_group_create();
                            NSString *systemPrompt = [HSBLocalLLMManager translationSystemPromptWithSource:sourceLanguage target:targetLanguage];
                            
                            for (NSDictionary *block in blocks) {
                                id rawBlockId = block[HSBRemotePayloadKeyId];
                                NSString *blockId = rawBlockId ? [NSString stringWithFormat:@"%@", rawBlockId] : nil;
                                NSString *text = block[HSBRemotePayloadKeyText];
                                if (blockId && text.length > 0) {
                                    dispatch_group_enter(group);
                                    
                                    [[HSBLocalLLMManager shared] processMessage:text systemPrompt:systemPrompt type:1 completion:^(NSString * _Nullable response, BOOL isFinished) {
                                        if (isFinished) {
                                            if (response) {
                                                translationMap[blockId] = response;
                                            }
                                            dispatch_group_leave(group);
                                        }
                                    }];
                                }
                            }
                            
                            dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                                [weakSelf sendPayload:@{
                                    HSBRemotePayloadKeyAction: HSBRemoteSimulateActionTranslationBlocksResult,
                                    HSBRemotePayloadKeyRequestId: requestId,
                                    HSBRemotePayloadKeyTranslationMap: translationMap
                                }];
                            });
                        }
                    }
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
