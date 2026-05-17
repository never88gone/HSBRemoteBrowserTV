//
//  HSBWatchSessionManager.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>
#import <WatchConnectivity/WatchConnectivity.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBWatchSessionManager : NSObject <WCSessionDelegate>

+ (instancetype)sharedManager;

- (void)startSession;
- (void)updateWatchSessionStateWithHandler:(void (^)(NSString *statusText))handler;

@end

NS_ASSUME_NONNULL_END
