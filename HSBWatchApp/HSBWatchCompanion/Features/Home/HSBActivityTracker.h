//
//  HSBActivityTracker.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol HSBActivityTrackerDelegate <NSObject>
@optional
- (void)activityTrackerDidUpdateSteps:(NSNumber *)steps;
- (void)activityTrackerDidUpdateProgress:(NSInteger)current target:(NSInteger)target isGoalReached:(BOOL)isGoalReached;
@end

@interface HSBActivityTracker : NSObject

@property (nonatomic, weak) id<HSBActivityTrackerDelegate> delegate;
@property (nonatomic, readonly) NSInteger dailyActionCount;
@property (nonatomic, readonly) NSInteger dailyTargetCount;

+ (instancetype)sharedTracker;

- (void)startTracking;
- (void)stopTracking;
- (void)incrementActionScore;
- (void)setTargetGoal:(NSInteger)target;
- (void)showSetGoalAlertFrom:(UIViewController *)presentingViewController;

@end

NS_ASSUME_NONNULL_END
