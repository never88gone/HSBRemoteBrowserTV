//
//  HSBWatchSessionManager.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>
#import <WatchConnectivity/WatchConnectivity.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const HSBWatchSessionReachabilityDidChangeNotification;
extern NSString * const HSBWatchActionReceivedNotification;

@interface HSBWatchSessionManager : NSObject <WCSessionDelegate>

+ (instancetype)sharedManager;

- (void)startSession;
- (void)updateWatchSessionStateWithHandler:(void (^)(NSString *statusText))handler;
- (void)handleIncomingPayload:(NSDictionary<NSString *, id> *)payload;

@end

NS_ASSUME_NONNULL_END
