//
//  HSBHomeVideoControlCard.m
//  HSBWatchCompanion
//

#import "HSBHomeVideoControlCard.h"

@interface HSBHomeVideoControlCard ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UISlider *videoSlider;
@property (nonatomic, assign) BOOL isDraggingSlider;

@end

@implementation HSBHomeVideoControlCard

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
    
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.05;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8;
    
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    BOOL isZH = [language hasPrefix:@"zh"];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = isZH ? @"电视播放进度" : @"VIDEO PLAYBACK";
    self.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.titleLabel];
    
    self.currentTimeLabel = [[UILabel alloc] init];
    self.currentTimeLabel.text = @"00:00";
    self.currentTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.currentTimeLabel.textColor = [UIColor whiteColor];
    self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.currentTimeLabel];
    
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.text = @"00:00";
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.durationLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.durationLabel];
    
    self.videoSlider = [[UISlider alloc] init];
    self.videoSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.videoSlider addTarget:self action:@selector(sliderTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.videoSlider addTarget:self action:@selector(sliderTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.videoSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.videoSlider];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        
        [self.currentTimeLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.currentTimeLabel.centerYAnchor constraintEqualToAnchor:self.videoSlider.centerYAnchor],
        
        [self.videoSlider.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:12],
        [self.videoSlider.leadingAnchor constraintEqualToAnchor:self.currentTimeLabel.trailingAnchor constant:10],
        [self.videoSlider.trailingAnchor constraintEqualToAnchor:self.durationLabel.leadingAnchor constant:-10],
        [self.videoSlider.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-20],
        
        [self.durationLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.durationLabel.centerYAnchor constraintEqualToAnchor:self.videoSlider.centerYAnchor],
    ]];
}

- (NSString *)formatTime:(NSTimeInterval)time {
    NSInteger minutes = (NSInteger)time / 60;
    NSInteger seconds = (NSInteger)time % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

- (void)sliderTouchDown:(UISlider *)slider {
    self.isDraggingSlider = YES;
}

- (void)sliderTouchUp:(UISlider *)slider {
    self.isDraggingSlider = NO;
    UINotificationFeedbackGenerator *hap = [[UINotificationFeedbackGenerator alloc] init];
    [hap notificationOccurred:UINotificationFeedbackTypeSuccess];
    if (self.onSeekRequested) {
        self.onSeekRequested(slider.value);
    }
}

- (void)sliderValueChanged:(UISlider *)slider {
    self.currentTimeLabel.text = [self formatTime:slider.value];
}

- (void)updateCurrentTime:(NSTimeInterval)current duration:(NSTimeInterval)duration {
    if (self.isDraggingSlider) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.videoSlider.maximumValue = (float)duration;
        self.videoSlider.value = (float)current;
        self.currentTimeLabel.text = [self formatTime:current];
        self.durationLabel.text = [self formatTime:duration];
    });
}

- (void)applyThemePrimaryColor:(UIColor *)color {
    self.videoSlider.tintColor = color;
}

@end
