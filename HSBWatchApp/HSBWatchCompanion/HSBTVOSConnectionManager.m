//
//  HSBTVOSConnectionManager.m
//  HSBWatchCompanion
//

#import "HSBTVOSConnectionManager.h"

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
                                                                  userInfo:@{@"state": @(state), @"message": @"🟢 Connected to Display"}];
                [weakSelf startReceivingFromTV];
                break;
            }
            case nw_connection_state_failed: {
                NSLog(@"[BonjourBridge] TVOS Connection failed: %@. Reconnecting in 2s...", error);
                weakSelf.isConnected = NO;
                weakSelf.connection = nil;
                [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSConnectionStateNotification 
                                                                    object:weakSelf 
                                                                  userInfo:@{@"state": @(state), @"message": @"🔴 Error. Reconnecting..."}];
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
                                                                  userInfo:@{@"state": @(state), @"message": @"⚪️ Disconnected"}];
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

- (void)sendAction:(NSString *)action withValue:(nullable NSString *)value {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"action"] = action;
    if (value) {
        payload[@"value"] = value;
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
    payload[@"action"] = @"update_home_json";
    payload[@"payload"] = jsonString;
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
                    NSString *action = json[@"action"];
                    if ([action isEqualToString:@"sync_progress"]) {
                        NSNumber *currentTime = json[@"currentTime"];
                        NSNumber *duration = json[@"duration"];
                        NSNumber *hiddenObj = json[@"hidden"];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSStateUpdatedNotification 
                                                                                object:weakSelf 
                                                                              userInfo:@{@"currentTime": currentTime ?: @(0), 
                                                                                         @"duration": duration ?: @(0), 
                                                                                         @"hidden": hiddenObj ?: @(NO)}];
                        });
                    } else if ([action isEqualToString:@"sync_favorites"]) {
                        NSArray *favorites = json[@"channels"];
                        if (favorites && [favorites isKindOfClass:[NSArray class]]) {
                            [[NSUserDefaults standardUserDefaults] setObject:favorites forKey:@"HSBIPTVFavorites"];
                            [[NSUserDefaults standardUserDefaults] synchronize];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:HSBIPTVFavoritesUpdatedNotification 
                                                                                    object:weakSelf 
                                                                                  userInfo:@{@"channels": favorites}];
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
