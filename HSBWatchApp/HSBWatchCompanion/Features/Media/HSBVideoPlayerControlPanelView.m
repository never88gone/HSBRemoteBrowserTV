//
//  HSBVideoPlayerControlPanelView.m
//  HSBWatchCompanion
//

#import "HSBVideoPlayerControlPanelView.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBVideoPlayerControlPanelView ()

@property (nonatomic, strong) UIButton *playPauseBtn;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UISegmentedControl *rateControl;
@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, strong) UIButton *muteBtn;
@property (nonatomic, strong) UIButton *audioTrackBtn;
@property (nonatomic, strong) UIButton *subtitleBtn;

@end

@implementation HSBVideoPlayerControlPanelView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    // --- Play / Pause ---
    self.playPauseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *bigConfig = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightBold];
    [self.playPauseBtn setImage:[UIImage systemImageNamed:@"pause.circle.fill" withConfiguration:bigConfig] forState:UIControlStateNormal];
    [self.playPauseBtn addTarget:self action:@selector(handlePlayPause) forControlEvents:UIControlEventTouchUpInside];
    self.playPauseBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.playPauseBtn];
    
    // --- Backward 10s ---
    UIButton *backBtn = [self createControlButtonWithIcon:@"gobackward.10" action:@selector(handleSeekBackward)];
    backBtn.tintColor = [UIColor whiteColor];
    [self addSubview:backBtn];
    
    // --- Forward 10s ---
    UIButton *fwdBtn = [self createControlButtonWithIcon:@"goforward.10" action:@selector(handleSeekForward)];
    fwdBtn.tintColor = [UIColor whiteColor];
    [self addSubview:fwdBtn];
    
    // --- Progress Slider ---
    self.progressSlider = [[UISlider alloc] init];
    self.progressSlider.minimumValue = 0;
    self.progressSlider.maximumValue = 1;
    self.progressSlider.value = 0;
    [self.progressSlider addTarget:self action:@selector(handleSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(handleSliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.progressSlider];
    
    // --- Time Labels ---
    self.currentTimeLabel = [[UILabel alloc] init];
    self.currentTimeLabel.text = @"00:00";
    self.currentTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.currentTimeLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.currentTimeLabel];
    
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.text = @"--:--";
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.durationLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.durationLabel];
    
    // --- Playback Rate ---
    UILabel *rateTitle = [[UILabel alloc] init];
    rateTitle.text = L(@"Playback Speed", @"播放速率");
    rateTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    rateTitle.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    rateTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:rateTitle];
    
    self.rateControl = [[UISegmentedControl alloc] initWithItems:@[@"0.5x", @"0.75x", @"1x", @"1.25x", @"1.5x", @"2x"]];
    self.rateControl.selectedSegmentIndex = 2; // 1x default
    [self.rateControl addTarget:self action:@selector(handleRateChanged:) forControlEvents:UIControlEventValueChanged];
    self.rateControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.rateControl];
    
    // --- Volume Control Section ---
    UILabel *volumeTitle = [[UILabel alloc] init];
    volumeTitle.text = L(@"Volume Control", @"电视音量");
    volumeTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    volumeTitle.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    volumeTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:volumeTitle];
    
    self.muteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *muteConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    [self.muteBtn setImage:[UIImage systemImageNamed:@"speaker.wave.2.fill" withConfiguration:muteConfig] forState:UIControlStateNormal];
    self.muteBtn.tintColor = [UIColor whiteColor];
    [self.muteBtn addTarget:self action:@selector(handleToggleMute) forControlEvents:UIControlEventTouchUpInside];
    self.muteBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.muteBtn];
    
    self.volumeSlider = [[UISlider alloc] init];
    self.volumeSlider.minimumValue = 0;
    self.volumeSlider.maximumValue = 1;
    self.volumeSlider.value = 1.0;
    [self.volumeSlider addTarget:self action:@selector(handleVolumeSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.volumeSlider addTarget:self action:@selector(handleVolumeSliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    self.volumeSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.volumeSlider];
    
    // --- Extra Features Row (Track & Subtitles) ---
    UIStackView *extraStack = [[UIStackView alloc] init];
    extraStack.axis = UILayoutConstraintAxisHorizontal;
    extraStack.spacing = 16;
    extraStack.distribution = UIStackViewDistributionFillEqually;
    extraStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:extraStack];
    
    self.audioTrackBtn = [self createFeatureCardWithIcon:@"waveform" title:L(@"Audio Track", @"音轨切换") action:@selector(handleSwitchAudioTrack)];
    [extraStack addArrangedSubview:self.audioTrackBtn];
    
    self.subtitleBtn = [self createFeatureCardWithIcon:@"captions.bubble" title:L(@"Subtitles", @"字幕切换") action:@selector(handleSwitchSubtitleTrack)];
    [extraStack addArrangedSubview:self.subtitleBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        // Transport Controls Row: [<<10] [▶️/⏸] [10>>]
        [self.playPauseBtn.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.playPauseBtn.topAnchor constraintEqualToAnchor:self.topAnchor constant:24],
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
        [self.currentTimeLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.currentTimeLabel.topAnchor constraintEqualToAnchor:self.playPauseBtn.bottomAnchor constant:24],
        
        [self.durationLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.durationLabel.centerYAnchor constraintEqualToAnchor:self.currentTimeLabel.centerYAnchor],
        
        [self.progressSlider.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.progressSlider.topAnchor constraintEqualToAnchor:self.currentTimeLabel.bottomAnchor constant:8],
        
        // Rate
        [rateTitle.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [rateTitle.topAnchor constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:24],
        
        [self.rateControl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.rateControl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.rateControl.topAnchor constraintEqualToAnchor:rateTitle.bottomAnchor constant:8],
        [self.rateControl.heightAnchor constraintEqualToConstant:36],
        
        // Volume Section
        [volumeTitle.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [volumeTitle.topAnchor constraintEqualToAnchor:self.rateControl.bottomAnchor constant:24],
        
        [self.muteBtn.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.muteBtn.topAnchor constraintEqualToAnchor:volumeTitle.bottomAnchor constant:12],
        [self.muteBtn.widthAnchor constraintEqualToConstant:36],
        [self.muteBtn.heightAnchor constraintEqualToConstant:36],
        
        [self.volumeSlider.leadingAnchor constraintEqualToAnchor:self.muteBtn.trailingAnchor constant:12],
        [self.volumeSlider.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.volumeSlider.centerYAnchor constraintEqualToAnchor:self.muteBtn.centerYAnchor],
        
        // Extra Features Row
        [extraStack.topAnchor constraintEqualToAnchor:self.volumeSlider.bottomAnchor constant:28],
        [extraStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [extraStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [extraStack.heightAnchor constraintEqualToConstant:48],
        [extraStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-30]
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

- (UIButton *)createFeatureCardWithIcon:(NSString *)icon title:(NSString *)title action:(SEL)sel {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.backgroundColor = [UIColor secondarySystemBackgroundColor];
    btn.layer.cornerRadius = 12;
    btn.layer.masksToBounds = YES;
    btn.tintColor = [UIColor whiteColor];
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
    [btn setImage:[UIImage systemImageNamed:icon withConfiguration:config] forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@"  %@", title] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)handlePlayPause { if (self.onPlayPauseToggled) self.onPlayPauseToggled(); }
- (void)handleSeekBackward { if (self.onSeekBackward) self.onSeekBackward(); }
- (void)handleSeekForward { if (self.onSeekForward) self.onSeekForward(); }
- (void)handleSliderChanged:(UISlider *)sender { if (self.onSliderChanged) self.onSliderChanged(sender.value); }
- (void)handleSliderEnded:(UISlider *)sender { if (self.onSliderEnded) self.onSliderEnded(sender.value); }

- (void)handleRateChanged:(UISegmentedControl *)sender {
    NSArray *rates = @[@0.5, @0.75, @1.0, @1.25, @1.5, @2.0];
    if (sender.selectedSegmentIndex < rates.count && self.onRateChanged) {
        self.onRateChanged([rates[sender.selectedSegmentIndex] doubleValue]);
    }
}

- (void)handleToggleMute { if (self.onToggleMute) self.onToggleMute(); }
- (void)handleVolumeSliderChanged:(UISlider *)sender { if (self.onVolumeChanged) self.onVolumeChanged(sender.value); }
- (void)handleVolumeSliderEnded:(UISlider *)sender { if (self.onVolumeEnded) self.onVolumeEnded(sender.value); }
- (void)handleSwitchAudioTrack { if (self.onSwitchAudioTrack) self.onSwitchAudioTrack(); }
- (void)handleSwitchSubtitleTrack { if (self.onSwitchSubtitleTrack) self.onSwitchSubtitleTrack(); }

- (void)updatePlayingState:(BOOL)isPlaying {
    UIImageSymbolConfiguration *bigConfig = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightBold];
    NSString *icon = isPlaying ? @"pause.circle.fill" : @"play.circle.fill";
    [self.playPauseBtn setImage:[UIImage systemImageNamed:icon withConfiguration:bigConfig] forState:UIControlStateNormal];
}

- (void)updateCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration isSeeking:(BOOL)isSeeking {
    if (!isSeeking && duration > 0) {
        self.progressSlider.value = currentTime / duration;
    }
    self.currentTimeLabel.text = [self formatTime:currentTime];
    if (duration > 0) {
        self.durationLabel.text = [self formatTime:duration];
    }
}

- (void)updatePlaybackRate:(double)rate {
    NSArray *rates = @[@0.5, @0.75, @1.0, @1.25, @1.5, @2.0];
    for (NSUInteger i = 0; i < rates.count; i++) {
        if (fabs([rates[i] doubleValue] - rate) < 0.05) {
            self.rateControl.selectedSegmentIndex = i;
            break;
        }
    }
}

- (void)updateVolume:(float)volume isMuted:(BOOL)isMuted {
    self.volumeSlider.value = volume;
    UIImageSymbolConfiguration *muteConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    NSString *icon = isMuted ? @"speaker.slash.fill" : (volume > 0.5 ? @"speaker.wave.2.fill" : @"speaker.wave.1.fill");
    [self.muteBtn setImage:[UIImage systemImageNamed:icon withConfiguration:muteConfig] forState:UIControlStateNormal];
}

- (void)applyThemePrimaryColor:(UIColor *)primaryColor {
    self.playPauseBtn.tintColor = primaryColor;
    self.progressSlider.minimumTrackTintColor = primaryColor;
    self.rateControl.selectedSegmentTintColor = primaryColor;
    self.volumeSlider.minimumTrackTintColor = primaryColor;
}

- (NSString *)formatTime:(NSTimeInterval)timeInSeconds {
    if (isnan(timeInSeconds) || timeInSeconds < 0) return @"00:00";
    NSInteger totalSeconds = (NSInteger)round(timeInSeconds);
    NSInteger minutes = totalSeconds / 60;
    NSInteger seconds = totalSeconds % 60;
    NSInteger hours = minutes / 60;
    minutes = minutes % 60;
    if (hours > 0) {
        return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
    } else {
        return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
    }
}

@end
