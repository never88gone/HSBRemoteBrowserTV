//
//  VideoControlViewController.m
//  HSBWatchCompanion
//

#import "VideoControlViewController.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface VideoControlViewController ()
@property (nonatomic, strong) UIButton *playPauseBtn;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UISegmentedControl *rateControl;
@property (nonatomic, assign) BOOL isPlaying;
@end

@implementation VideoControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.isPlaying = YES;
    
    // --- Play / Pause ---
    self.playPauseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *bigConfig = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightBold];
    [self.playPauseBtn setImage:[UIImage systemImageNamed:@"pause.circle.fill" withConfiguration:bigConfig] forState:UIControlStateNormal];
    self.playPauseBtn.tintColor = [UIColor systemBlueColor];
    [self.playPauseBtn addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    self.playPauseBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.playPauseBtn];
    
    // --- Backward 10s ---
    UIButton *backBtn = [self createControlButtonWithIcon:@"gobackward.10" action:@selector(seekBackward)];
    [self.view addSubview:backBtn];
    
    // --- Forward 10s ---
    UIButton *fwdBtn = [self createControlButtonWithIcon:@"goforward.10" action:@selector(seekForward)];
    [self.view addSubview:fwdBtn];
    
    // --- Progress Slider ---
    self.progressSlider = [[UISlider alloc] init];
    self.progressSlider.minimumValue = 0;
    self.progressSlider.maximumValue = 1;
    self.progressSlider.value = 0;
    self.progressSlider.tintColor = [UIColor systemBlueColor];
    [self.progressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(sliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.progressSlider];
    
    // --- Time Labels ---
    self.currentTimeLabel = [[UILabel alloc] init];
    self.currentTimeLabel.text = @"00:00";
    self.currentTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.currentTimeLabel.textColor = [UIColor secondaryLabelColor];
    self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.currentTimeLabel];
    
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.text = @"--:--";
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.durationLabel.textColor = [UIColor secondaryLabelColor];
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.durationLabel];
    
    // --- Playback Rate ---
    UILabel *rateTitle = [[UILabel alloc] init];
    rateTitle.text = L(@"Playback Speed", @"播放速率");
    rateTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    rateTitle.textColor = [UIColor secondaryLabelColor];
    rateTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:rateTitle];
    
    self.rateControl = [[UISegmentedControl alloc] initWithItems:@[@"0.5x", @"0.75x", @"1x", @"1.25x", @"1.5x", @"2x"]];
    self.rateControl.selectedSegmentIndex = 2; // 1x default
    [self.rateControl addTarget:self action:@selector(rateChanged:) forControlEvents:UIControlEventValueChanged];
    self.rateControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.rateControl];
    
    // --- Layout ---
    [NSLayoutConstraint activateConstraints:@[
        // Transport Controls Row: [<<10] [▶️/⏸] [10>>]
        [self.playPauseBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.playPauseBtn.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:40],
        [self.playPauseBtn.widthAnchor constraintEqualToConstant:70],
        [self.playPauseBtn.heightAnchor constraintEqualToConstant:70],
        
        [backBtn.trailingAnchor constraintEqualToAnchor:self.playPauseBtn.leadingAnchor constant:-30],
        [backBtn.centerYAnchor constraintEqualToAnchor:self.playPauseBtn.centerYAnchor],
        [backBtn.widthAnchor constraintEqualToConstant:50],
        [backBtn.heightAnchor constraintEqualToConstant:50],
        
        [fwdBtn.leadingAnchor constraintEqualToAnchor:self.playPauseBtn.trailingAnchor constant:30],
        [fwdBtn.centerYAnchor constraintEqualToAnchor:self.playPauseBtn.centerYAnchor],
        [fwdBtn.widthAnchor constraintEqualToConstant:50],
        [fwdBtn.heightAnchor constraintEqualToConstant:50],
        
        // Progress Slider
        [self.currentTimeLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.currentTimeLabel.topAnchor constraintEqualToAnchor:self.playPauseBtn.bottomAnchor constant:30],
        
        [self.durationLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.durationLabel.centerYAnchor constraintEqualToAnchor:self.currentTimeLabel.centerYAnchor],
        
        [self.progressSlider.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.progressSlider.topAnchor constraintEqualToAnchor:self.currentTimeLabel.bottomAnchor constant:8],
        
        // Rate
        [rateTitle.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [rateTitle.topAnchor constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:30],
        
        [self.rateControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.rateControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.rateControl.topAnchor constraintEqualToAnchor:rateTitle.bottomAnchor constant:10],
        [self.rateControl.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (UIButton *)createControlButtonWithIcon:(NSString *)icon action:(SEL)sel {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightMedium];
    [btn setImage:[UIImage systemImageNamed:icon withConfiguration:config] forState:UIControlStateNormal];
    btn.tintColor = [UIColor labelColor];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    return btn;
}

#pragma mark - Actions

- (void)togglePlayPause {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    
    self.isPlaying = !self.isPlaying;
    UIImageSymbolConfiguration *bigConfig = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightBold];
    NSString *icon = self.isPlaying ? @"pause.circle.fill" : @"play.circle.fill";
    [self.playPauseBtn setImage:[UIImage systemImageNamed:icon withConfiguration:bigConfig] forState:UIControlStateNormal];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{@"action": self.isPlaying ? @"video_play" : @"video_pause"});
    }
}

- (void)seekBackward {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{@"action": @"seek_relative", @"value": @(-10)});
    }
}

- (void)seekForward {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{@"action": @"seek_relative", @"value": @(10)});
    }
}

- (void)sliderChanged:(UISlider *)slider {
    // Update time label during dragging (visual only)
}

- (void)sliderEnded:(UISlider *)slider {
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{@"action": @"seek_percent", @"value": @(slider.value)});
    }
}

- (void)rateChanged:(UISegmentedControl *)seg {
    NSArray *rates = @[@0.5, @0.75, @1.0, @1.25, @1.5, @2.0];
    NSNumber *rate = rates[seg.selectedSegmentIndex];
    
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{@"action": @"set_rate", @"value": rate});
    }
}

@end
