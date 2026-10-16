//
//  HSBActivityTracker.m
//  HSBWatchCompanion
//

#import "HSBActivityTracker.h"
#import <CoreMotion/CoreMotion.h>

@interface HSBActivityTracker ()

@property (nonatomic, strong) CMPedometer *pedometer;
@property (nonatomic, assign) NSInteger dailyActionCount;
@property (nonatomic, assign) NSInteger dailyTargetCount;

@end

@implementation HSBActivityTracker

+ (instancetype)sharedTracker {
    static HSBActivityTracker *tracker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tracker = [[self alloc] init];
    });
    return tracker;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadPersistedStats];
    }
    return self;
}

- (NSString *)todayStorageKey {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyyMMdd";
    return [NSString stringWithFormat:@"ActivityCount_%@", [df stringFromDate:[NSDate date]]];
}

- (void)loadPersistedStats {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.dailyActionCount = [defaults integerForKey:[self todayStorageKey]];
    self.dailyTargetCount = [defaults integerForKey:@"ActivityTargetCount"];
    if (self.dailyTargetCount <= 0) {
        self.dailyTargetCount = 100;
    }
}

- (void)startTracking {
    [self loadPersistedStats];
    [self notifyProgressChanged];
    
    if ([CMPedometer isStepCountingAvailable]) {
        if (!self.pedometer) {
            self.pedometer = [[CMPedometer alloc] init];
        }
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *midnight = [calendar startOfDayForDate:[NSDate date]];
        
        __weak typeof(self) weakSelf = self;
        [self.pedometer startPedometerUpdatesFromDate:midnight withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
            if (!error && pedometerData) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([weakSelf.delegate respondsToSelector:@selector(activityTrackerDidUpdateSteps:)]) {
                        [weakSelf.delegate activityTrackerDidUpdateSteps:pedometerData.numberOfSteps];
                    }
                });
            }
        }];
    }
}

- (void)stopTracking {
    [self.pedometer stopPedometerUpdates];
}

- (void)incrementActionScore {
    self.dailyActionCount++;
    [[NSUserDefaults standardUserDefaults] setInteger:self.dailyActionCount forKey:[self todayStorageKey]];
    [self notifyProgressChanged];
}

- (void)setTargetGoal:(NSInteger)target {
    if (target <= 0) return;
    self.dailyTargetCount = target;
    [[NSUserDefaults standardUserDefaults] setInteger:self.dailyTargetCount forKey:@"ActivityTargetCount"];
    [self notifyProgressChanged];
}

- (void)notifyProgressChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL isReached = (self.dailyActionCount >= self.dailyTargetCount);
        if ([self.delegate respondsToSelector:@selector(activityTrackerDidUpdateProgress:target:isGoalReached:)]) {
            [self.delegate activityTrackerDidUpdateProgress:self.dailyActionCount target:self.dailyTargetCount isGoalReached:isReached];
        }
    });
}

- (void)showSetGoalAlertFrom:(UIViewController *)presentingViewController {
    if (!presentingViewController) return;
    
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    BOOL isZH = [language hasPrefix:@"zh"];
    NSString *title = isZH ? @"设置每日目标" : @"Define Goal";
    NSString *msg = isZH ? @"请输入您设定的每日训练动作目标次数" : @"Set your daily target gestures";
    NSString *saveTitle = isZH ? @"保存" : @"Save";
    NSString *cancelTitle = isZH ? @"取消" : @"Cancel";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)weakSelf.dailyTargetCount];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:saveTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *text = alert.textFields.firstObject.text;
        if (text && text.integerValue > 0) {
            [weakSelf setTargetGoal:text.integerValue];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleCancel handler:nil]];
    [presentingViewController presentViewController:alert animated:YES completion:nil];
}

@end
