//
//  HSBTVOSHeartbeatCoordinator.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HSBTVOSHeartbeatCoordinator;

@protocol HSBTVOSHeartbeatCoordinatorDelegate <NSObject>
- (void)heartbeatCoordinatorDidTriggerPing:(HSBTVOSHeartbeatCoordinator *)coordinator;
- (void)heartbeatCoordinatorDidTriggerReconnect:(HSBTVOSHeartbeatCoordinator *)coordinator;
@end

@interface HSBTVOSHeartbeatCoordinator : NSObject

@property (nonatomic, weak) id<HSBTVOSHeartbeatCoordinatorDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isReconnecting;
@property (nonatomic, assign, readonly) NSUInteger reconnectAttemptCount;

- (instancetype)initWithQueue:(dispatch_queue_t)queue;

- (void)startHeartbeat;
- (void)stopHeartbeat;

- (void)scheduleReconnectWithDelay:(NSTimeInterval)delay;
- (void)stopReconnect;
- (void)resetReconnectAttempts;

- (void)suspendAll;

@end

NS_ASSUME_NONNULL_END
