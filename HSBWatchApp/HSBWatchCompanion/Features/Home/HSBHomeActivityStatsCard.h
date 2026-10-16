//
//  HSBHomeActivityStatsCard.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBHomeActivityStatsCard : UIView

@property (nonatomic, copy, nullable) void (^onAdjustGoalRequested)(void);

- (void)updateSteps:(NSNumber *)steps;
- (void)updateProgress:(NSInteger)current target:(NSInteger)target isGoalReached:(BOOL)isGoalReached;

@end

NS_ASSUME_NONNULL_END
