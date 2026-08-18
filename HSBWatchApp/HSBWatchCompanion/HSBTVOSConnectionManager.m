//
//  HSBTVOSConnectionManager.m
//  HSBWatchCompanion
//

#import "HSBTVOSConnectionManager.h"
#import "HSBLocalLLMManager.h"

NSString * const HSBTVOSConnectionStateNotification = @"HSBTVOSConnectionStateNotification";
NSString * const HSBTVOSStateUpdatedNotification = @"HSBTVOSStateUpdatedNotification";
NSString * const HSBIPTVFavoritesUpdatedNotification = @"HSBIPTVFavoritesUpdatedNotification";

@interface HSBTVOSConnectionManager ()

@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, strong, nullable) nw_connection_t connection;
@property (nonatomic, copy, nullable) NSString *deviceName;
@property (nonatomic, strong, nullable) nw_endpoint_t currentEndpoint;
@property (nonatomic, strong) dispatch_queue_t queue;

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
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_include_peer_to_peer(parameters, true);
    return parameters;
}

- (void)connectToEndpoint:(nw_endpoint_t)endpoint deviceName:(NSString *)deviceName {
    self.currentEndpoint = endpoint;
    self.deviceName = deviceName;
    
    if (self.connection) {
        nw_connection_cancel(self.connection);
        self.connection = nil;
    }
    
    nw_parameters_t parameters = [self createTCPParameters];
    self.connection = nw_connection_create(endpoint, parameters);
    
    __weak typeof(self) weakSelf = self;
    nw_connection_set_state_changed_handler(self.connection, ^(nw_connection_state_t state, nw_error_t error) {
        switch (state) {
            case nw_connection_state_ready: {
                NSLog(@"[BonjourBridge] Connected to TVOS Display!");
                weakSelf.isConnected = YES;
                [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification 
                                                                    object:weakSelf 
                                                                  userInfo:@{HSBConnectionStateKeyState: @(state), HSBConnectionStateKeyMessage: @"🟢 Connected to Display"}];
                [weakSelf startReceivingFromTV];
                break;
            }
            case nw_connection_state_failed: {
                NSLog(@"[BonjourBridge] TVOS Connection failed: %@. Reconnecting in 2s...", error);
                weakSelf.isConnected = NO;
                weakSelf.connection = nil;
                [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification 
                                                                    object:weakSelf 
                                                                  userInfo:@{HSBConnectionStateKeyState: @(state), HSBConnectionStateKeyMessage: @"🔴 Error. Reconnecting..."}];
                // Auto-reconnect after 2 seconds
                if (weakSelf.currentEndpoint) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), weakSelf.queue, ^{
                        [weakSelf connectToEndpoint:weakSelf.currentEndpoint deviceName:weakSelf.deviceName];
                    });
                }
                break;
            }
            case nw_connection_state_cancelled: {
                NSLog(@"[BonjourBridge] TVOS Connection cancelled.");
                weakSelf.isConnected = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification 
                                                                    object:weakSelf 
                                                                  userInfo:@{HSBConnectionStateKeyState: @(state), HSBConnectionStateKeyMessage: @"⚪️ Disconnected"}];
                break;
            }
            default:
                break;
        }
    });
    
    nw_connection_set_queue(self.connection, self.queue);
    nw_connection_start(self.connection);
}

- (void)disconnect {
    self.currentEndpoint = nil;
    self.deviceName = nil;
    if (self.connection) {
        nw_connection_cancel(self.connection);
        self.connection = nil;
    }
    self.isConnected = NO;
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

- (void)startReceivingFromTV {
    if (!self.connection) return;
    
    __weak typeof(self) weakSelf = self;
    nw_connection_receive(self.connection, 1, 65536, ^(dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_error_t error) {
        if (content) {
            const void *buffer = NULL;
            size_t size = 0;
            dispatch_data_t contiguousContent = dispatch_data_create_map(content, &buffer, &size);
            if (buffer && size > 0) {
                NSData *data = [NSData dataWithBytes:buffer length:size];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (json && [json isKindOfClass:[NSDictionary class]]) {
                    NSString *action = json[HSBRemotePayloadKeyAction];
                    if ([action isEqualToString:HSBRemoteSimulateActionSyncProgress]) {
                        NSNumber *currentTime = json[HSBRemotePayloadKeyCurrentTime];
                        NSNumber *duration = json[HSBRemotePayloadKeyDuration];
                        NSNumber *hiddenObj = json[HSBRemotePayloadKeyHidden];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSStateUpdatedNotification 
                                                                                object:weakSelf 
                                                                              userInfo:@{HSBRemotePayloadKeyCurrentTime: currentTime ?: @(0), 
                                                                                         HSBRemotePayloadKeyDuration: duration ?: @(0), 
                                                                                         HSBRemotePayloadKeyHidden: hiddenObj ?: @(NO)}];
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
        
        if (!is_complete && !error) {
            [weakSelf startReceivingFromTV];
        }
    });
}

@end
