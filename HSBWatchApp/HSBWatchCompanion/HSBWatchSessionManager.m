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

NSString * const HSBWatchSessionReachabilityDidChangeNotification = @"HSBWatchSessionReachabilityDidChangeNotification";
NSString * const HSBWatchActionReceivedNotification = @"HSBWatchActionReceivedNotification";

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
            WCSession *session = WCSession.defaultSession;
            if (session.activationState == WCSessionActivationStateActivated) {
                if (!session.isPaired) {
                    handler(L(@"🔴 No Apple Watch Paired", @"🔴 未配对 Apple Watch"));
                } else if (!session.isWatchAppInstalled) {
                    handler(L(@"🟡 Watch App Not Installed", @"🟡 Apple Watch 未安装配套应用"));
                } else if (session.isReachable) {
                    handler(L(@"🟢 Connected to Watch App", @"🟢 手表端已连接 (实时传输中)"));
                } else {
                    handler(L(@"🟡 Watch App in Background", @"🟡 手表端应用处于后台/放腕中"));
                }
            } else {
                handler(L(@"🔴 Watch Session Inactive", @"🔴 手表通道未激活，正在启动..."));
                [session activateSession];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:HSBWatchSessionReachabilityDidChangeNotification object:nil userInfo:@{@"isReachable": @(session.isReachable)}];
    });
}

- (void)sessionReachabilityDidChange:(WCSession *)session {
    NSLog(@"[BonjourBridge] Watch Session Reachability Changed: %d", session.isReachable);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:HSBWatchSessionReachabilityDidChangeNotification object:nil userInfo:@{@"isReachable": @(session.isReachable)}];
    });
}

- (void)sessionWatchStateDidChange:(WCSession *)session {
    NSLog(@"[BonjourBridge] Watch Session State Changed: paired=%d, installed=%d", session.isPaired, session.isWatchAppInstalled);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:HSBWatchSessionReachabilityDidChangeNotification object:nil userInfo:@{@"isReachable": @(session.isReachable)}];
    });
}

- (void)sessionDidBecomeInactive:(WCSession *)session {
    NSLog(@"[BonjourBridge] Watch Session Did Become Inactive");
}

- (void)sessionDidDeactivate:(WCSession *)session {
    NSLog(@"[BonjourBridge] Watch Session Did Deactivate");
    [WCSession.defaultSession activateSession];
}

- (void)handleIncomingPayload:(NSDictionary<NSString *,id> *)payload {
    NSString *action = payload[@"action"] ?: payload[HSBRemotePayloadKeyAction];
    NSLog(@"[BonjourBridge] Watch incoming payload action: %@", action);
    
    // 广播通知主界面以供实时体感动作显示与触觉确认
    if (action.length > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HSBWatchActionReceivedNotification
                                                                object:nil
                                                              userInfo:payload];
        });
    }
    
    // 中介转发逻辑：将手表的控制 payload 发给 TVOS！
    if ([HSBTVOSConnectionManager sharedManager].isConnected) {
        [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    }
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message {
    NSLog(@"[BonjourBridge] Watch received message: %@", message);
    [self handleIncomingPayload:message];
}

- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *,id> *)userInfo {
    NSLog(@"[BonjourBridge] Watch received UserInfo: %@", userInfo);
    [self handleIncomingPayload:userInfo];
}

@end
