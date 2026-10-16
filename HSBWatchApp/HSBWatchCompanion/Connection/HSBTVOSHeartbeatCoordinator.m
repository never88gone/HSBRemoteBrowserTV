//
//  HSBTVOSHeartbeatCoordinator.m
//  HSBWatchCompanion
//

#import "HSBTVOSHeartbeatCoordinator.h"

@interface HSBTVOSHeartbeatCoordinator ()

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) BOOL isReconnecting;
@property (nonatomic, assign) NSUInteger reconnectAttemptCount;
@property (nonatomic, strong, nullable) dispatch_source_t reconnectTimer;
@property (nonatomic, strong, nullable) dispatch_source_t heartbeatTimer;

@end

@implementation HSBTVOSHeartbeatCoordinator

- (instancetype)initWithQueue:(dispatch_queue_t)queue {
    self = [super init];
    if (self) {
        _queue = queue;
        _isReconnecting = NO;
        _reconnectAttemptCount = 0;
    }
    return self;
}

- (void)startHeartbeat {
    [self stopHeartbeat];
    
    __weak typeof(self) weakSelf = self;
    self.heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_timer(self.heartbeatTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC),
                              10 * NSEC_PER_SEC,
                              1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.heartbeatTimer, ^{
        if ([weakSelf.delegate respondsToSelector:@selector(heartbeatCoordinatorDidTriggerPing:)]) {
            [weakSelf.delegate heartbeatCoordinatorDidTriggerPing:weakSelf];
        }
    });
    dispatch_resume(self.heartbeatTimer);
}

- (void)stopHeartbeat {
    if (self.heartbeatTimer) {
        dispatch_source_cancel(self.heartbeatTimer);
        self.heartbeatTimer = nil;
    }
}

- (void)scheduleReconnectWithDelay:(NSTimeInterval)delay {
    [self stopReconnect];
    
    self.isReconnecting = YES;
    self.reconnectAttemptCount++;
    
    NSTimeInterval actualDelay = delay;
    if (actualDelay <= 0) {
        actualDelay = MIN(1.0 + (self.reconnectAttemptCount * 0.8), 5.0);
    }
    
    NSLog(@"[BonjourBridge] Scheduling reconnect attempt #%lu in %.1fs...", (unsigned long)self.reconnectAttemptCount, actualDelay);
    
    __weak typeof(self) weakSelf = self;
    self.reconnectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_timer(self.reconnectTimer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(actualDelay * NSEC_PER_SEC)),
                              DISPATCH_TIME_FOREVER,
                              100 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(self.reconnectTimer, ^{
        [weakSelf stopReconnect];
        if ([weakSelf.delegate respondsToSelector:@selector(heartbeatCoordinatorDidTriggerReconnect:)]) {
            [weakSelf.delegate heartbeatCoordinatorDidTriggerReconnect:weakSelf];
        }
    });
    dispatch_resume(self.reconnectTimer);
}

- (void)stopReconnect {
    if (self.reconnectTimer) {
        dispatch_source_cancel(self.reconnectTimer);
        self.reconnectTimer = nil;
    }
    self.isReconnecting = NO;
}

- (void)resetReconnectAttempts {
    self.reconnectAttemptCount = 0;
}

- (void)suspendAll {
    [self stopHeartbeat];
    [self stopReconnect];
}

- (void)dealloc {
    [self suspendAll];
}

@end
