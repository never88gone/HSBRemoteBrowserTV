//
//  HSBHomeActivityStatsCard.m
//  HSBWatchCompanion
//

#import "HSBHomeActivityStatsCard.h"

@interface HSBHomeActivityStatsCard ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UILabel *stepsLabel;
@property (nonatomic, strong) UIButton *goalButton;

@end

@implementation HSBHomeActivityStatsCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    self.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.layer.cornerRadius = 16;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    BOOL isZH = [language hasPrefix:@"zh"];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = isZH ? @"每日训练目标" : @"DAILY TRAINING GOAL";
    self.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.titleLabel];
    
    self.statsLabel = [[UILabel alloc] init];
    self.statsLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.statsLabel.textColor = [UIColor whiteColor];
    self.statsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.statsLabel];
    
    self.stepsLabel = [[UILabel alloc] init];
    self.stepsLabel.text = isZH ? @"今日设备走动步数: 统计中..." : @"Local Steps (Today): Detecting...";
    self.stepsLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    self.stepsLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    self.stepsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.stepsLabel];
    
    self.goalButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.goalButton setTitle:isZH ? @"调整目标" : @"Set Goal" forState:UIControlStateNormal];
    self.goalButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [self.goalButton addTarget:self action:@selector(handleGoalTapped) forControlEvents:UIControlEventTouchUpInside];
    self.goalButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.goalButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.goalButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.goalButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.statsLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
        [self.statsLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.statsLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.stepsLabel.topAnchor constraintEqualToAnchor:self.statsLabel.bottomAnchor constant:4],
        [self.stepsLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.stepsLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.stepsLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-14]
    ]];
}

- (void)handleGoalTapped {
    if (self.onAdjustGoalRequested) {
        self.onAdjustGoalRequested();
    }
}

- (void)updateSteps:(NSNumber *)steps {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    BOOL isZH = [language hasPrefix:@"zh"];
    NSString *fmt = isZH ? @"今日设备走动步数: %@" : @"Local Steps (Today): %@";
    self.stepsLabel.text = [NSString stringWithFormat:fmt, steps];
}

- (void)updateProgress:(NSInteger)current target:(NSInteger)target isGoalReached:(BOOL)isGoalReached {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    BOOL isZH = [language hasPrefix:@"zh"];
    NSString *fmt = isZH ? @"今日达成: %ld / %ld 的目标频次" : @"Today's Progress: %ld / %ld";
    self.statsLabel.text = [NSString stringWithFormat:fmt, (long)current, (long)target];
    self.statsLabel.textColor = isGoalReached ? [UIColor systemGreenColor] : [UIColor whiteColor];
}

@end
