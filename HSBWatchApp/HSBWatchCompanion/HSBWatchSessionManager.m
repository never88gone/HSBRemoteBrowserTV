//
//  HSBWatchSessionManager.m
//  HSBWatchCompanion
//

#import "HSBWatchSessionManager.h"
#import "HSBTVOSConnectionManager.h"

static NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@implementation HSBWatchSessionManager

+ (instancetype)sharedManager {
    static HSBWatchSessionManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HSBWatchSessionManager alloc] init];
    });
    return instance;
}

- (void)startSession {
    if ([WCSession isSupported]) {
        WCSession.defaultSession.delegate = self;
        [WCSession.defaultSession activateSession];
        NSLog(@"[BonjourBridge] HSBWatchSessionManager WCSession Activated...");
    }
}

- (void)updateWatchSessionStateWithHandler:(void (^)(NSString *statusText))handler {
    if (!handler) return;
    
    if ([WCSession isSupported]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            WCSessionActivationState state = WCSession.defaultSession.activationState;
            if (state == WCSessionActivationStateActivated) {
                if (WCSession.defaultSession.isReachable) {
                    handler(L(@"🟢 Connected to Watch App", @"🟢 手表端应用连接成功"));
                } else {
                    handler(L(@"🟡 Watch App in Background", @"🟡 手表端应用处于后台/未启动"));
                }
            } else {
                handler(L(@"🔴 Watch Session Inactive", @"🔴 手表通道未激活，正在启动..."));
                [WCSession.defaultSession activateSession];
            }
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(L(@"🔴 WCSession Not Supported", @"🔴 当前设备不支持 WCSession"));
        });
    }
}

#pragma mark - WCSessionDelegate

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(NSError *)error {
    if (error) {
        NSLog(@"[BonjourBridge] Watch Session Activation Error: %@", error.localizedDescription);
    } else {
        NSLog(@"[BonjourBridge] Watch Session Activation Completed, State: %ld", (long)activationState);
    }
}

- (void)sessionDidBecomeInactive:(WCSession *)session {
    NSLog(@"[BonjourBridge] Watch Session Did Become Inactive");
}

- (void)sessionDidDeactivate:(WCSession *)session {
    NSLog(@"[BonjourBridge] Watch Session Did Deactivate");
    [WCSession.defaultSession activateSession];
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message {
    NSLog(@"[BonjourBridge] Watch received message: %@", message);
    
    // 中介转发逻辑：将手表的控制 payload 直接发给 TVOS！
    if ([HSBTVOSConnectionManager sharedManager].isConnected) {
        [[HSBTVOSConnectionManager sharedManager] sendPayload:message];
    }
}

- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *,id> *)userInfo {
    NSLog(@"[BonjourBridge] Watch received UserInfo: %@", userInfo);
    
    // 同样也中转给电视端！
    if ([HSBTVOSConnectionManager sharedManager].isConnected) {
        [[HSBTVOSConnectionManager sharedManager] sendPayload:userInfo];
    }
}

@end
