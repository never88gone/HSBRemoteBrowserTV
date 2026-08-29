//
//  VideoControlViewController.m
//  HSBWatchCompanion
//

#import "VideoControlViewController.h"
#import "HSBThemeManager.h"
#import "HSBTVOSConnectionManager.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface VideoControlViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIButton *playPauseBtn;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UISegmentedControl *rateControl;
@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, strong) UIButton *muteBtn;
@property (nonatomic, strong) UIButton *audioTrackBtn;
@property (nonatomic, strong) UIButton *subtitleBtn;
@property (nonatomic, strong) MPVolumeView *hiddenVolumeView;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, assign) BOOL isDraggingSlider;
@property (nonatomic, assign) BOOL isDraggingVolume;
@property (nonatomic, assign) NSTimeInterval currentDuration;
@property (nonatomic, assign) float initialVolume;
@property (nonatomic, assign) BOOL isObservingVolume;
@end

@implementation VideoControlViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopVolumeObservation];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isPlaying = YES;
    self.isMuted = NO;
    self.currentDuration = 0;
    self.isDraggingSlider = NO;
    self.isDraggingVolume = NO;
    
    // 监听 tvOS 状态更新通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTVOSStateUpdated:)
                                                 name:HSBTVOSStateUpdatedNotification
                                               object:nil];
    
    [self setupUI];
    [self setupHiddenVolumeView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startVolumeObservation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopVolumeObservation];
}

#pragma mark - Physical Volume Button Listening

- (void)setupHiddenVolumeView {
    self.hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1000, -1000, 1, 1)];
    self.hiddenVolumeView.alpha = 0.01;
    [self.view addSubview:self.hiddenVolumeView];
}

- (void)startVolumeObservation {
    if (self.isObservingVolume) return;
    NSError *err = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:&err];
    self.initialVolume = session.outputVolume;
    [session addObserver:self
              forKeyPath:@"outputVolume"
                 options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                 context:nil];
    self.isObservingVolume = YES;
}

- (void)stopVolumeObservation {
    if (!self.isObservingVolume) return;
    @try {
        [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
    } @catch (NSException *exception) {}
    self.isObservingVolume = NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"outputVolume"]) {
        float oldVol = [change[NSKeyValueChangeOldKey] floatValue];
        float newVol = [change[NSKeyValueChangeNewKey] floatValue];
        if (newVol > oldVol) {
            [self volumeUp];
        } else if (newVol < oldVol) {
            [self volumeDown];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - UI Setup

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    
    // --- Play / Pause ---
    self.playPauseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *bigConfig = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightBold];
    [self.playPauseBtn setImage:[UIImage systemImageNamed:@"pause.circle.fill" withConfiguration:bigConfig] forState:UIControlStateNormal];
    self.playPauseBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self.playPauseBtn addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    self.playPauseBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.playPauseBtn];
    
    // --- Backward 10s ---
    UIButton *backBtn = [self createControlButtonWithIcon:@"gobackward.10" action:@selector(seekBackward)];
    backBtn.tintColor = [UIColor whiteColor];
    [self.contentView addSubview:backBtn];
    
    // --- Forward 10s ---
    UIButton *fwdBtn = [self createControlButtonWithIcon:@"goforward.10" action:@selector(seekForward)];
    fwdBtn.tintColor = [UIColor whiteColor];
    [self.contentView addSubview:fwdBtn];
    
    // --- Progress Slider ---
    self.progressSlider = [[UISlider alloc] init];
    self.progressSlider.minimumValue = 0;
    self.progressSlider.maximumValue = 1;
    self.progressSlider.value = 0;
    self.progressSlider.minimumTrackTintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self.progressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(sliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.progressSlider];
    
    // --- Time Labels ---
    self.currentTimeLabel = [[UILabel alloc] init];
    self.currentTimeLabel.text = @"00:00";
    self.currentTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.currentTimeLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.currentTimeLabel];
    
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.text = @"--:--";
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.durationLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.durationLabel];
    
    // --- Playback Rate ---
    UILabel *rateTitle = [[UILabel alloc] init];
    rateTitle.text = L(@"Playback Speed", @"播放速率");
    rateTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    rateTitle.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    rateTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:rateTitle];
    
    self.rateControl = [[UISegmentedControl alloc] initWithItems:@[@"0.5x", @"0.75x", @"1x", @"1.25x", @"1.5x", @"2x"]];
    self.rateControl.selectedSegmentIndex = 2; // 1x default
    self.rateControl.selectedSegmentTintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self.rateControl addTarget:self action:@selector(rateChanged:) forControlEvents:UIControlEventValueChanged];
    self.rateControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.rateControl];
    
    // --- Volume Control Section ---
    UILabel *volumeTitle = [[UILabel alloc] init];
    volumeTitle.text = L(@"Volume Control", @"电视音量");
    volumeTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    volumeTitle.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    volumeTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:volumeTitle];
    
    self.muteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *muteConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    [self.muteBtn setImage:[UIImage systemImageNamed:@"speaker.wave.2.fill" withConfiguration:muteConfig] forState:UIControlStateNormal];
    self.muteBtn.tintColor = [UIColor whiteColor];
    [self.muteBtn addTarget:self action:@selector(toggleMute) forControlEvents:UIControlEventTouchUpInside];
    self.muteBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.muteBtn];
    
    self.volumeSlider = [[UISlider alloc] init];
    self.volumeSlider.minimumValue = 0;
    self.volumeSlider.maximumValue = 1;
    self.volumeSlider.value = 1.0;
    self.volumeSlider.minimumTrackTintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self.volumeSlider addTarget:self action:@selector(volumeSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.volumeSlider addTarget:self action:@selector(volumeSliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    self.volumeSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.volumeSlider];
    
    // --- Extra Features Row (Track & Subtitles) ---
    UIStackView *extraStack = [[UIStackView alloc] init];
    extraStack.axis = UILayoutConstraintAxisHorizontal;
    extraStack.spacing = 16;
    extraStack.distribution = UIStackViewDistributionFillEqually;
    extraStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:extraStack];
    
    self.audioTrackBtn = [self createFeatureCardWithIcon:@"waveform" title:L(@"Audio Track", @"音轨切换") action:@selector(switchAudioTrack)];
    [extraStack addArrangedSubview:self.audioTrackBtn];
    
    self.subtitleBtn = [self createFeatureCardWithIcon:@"captions.bubble" title:L(@"Subtitles", @"字幕切换") action:@selector(switchSubtitleTrack)];
    [extraStack addArrangedSubview:self.subtitleBtn];
    
    // --- Layout Constraints ---
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
        
        // Transport Controls Row: [<<10] [▶️/⏸] [10>>]
        [self.playPauseBtn.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.playPauseBtn.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:24],
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
        [self.currentTimeLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.currentTimeLabel.topAnchor constraintEqualToAnchor:self.playPauseBtn.bottomAnchor constant:24],
        
        [self.durationLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.durationLabel.centerYAnchor constraintEqualToAnchor:self.currentTimeLabel.centerYAnchor],
        
        [self.progressSlider.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.progressSlider.topAnchor constraintEqualToAnchor:self.currentTimeLabel.bottomAnchor constant:8],
        
        // Rate
        [rateTitle.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [rateTitle.topAnchor constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:24],
        
        [self.rateControl.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.rateControl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.rateControl.topAnchor constraintEqualToAnchor:rateTitle.bottomAnchor constant:8],
        [self.rateControl.heightAnchor constraintEqualToConstant:36],
        
        // Volume Section
        [volumeTitle.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [volumeTitle.topAnchor constraintEqualToAnchor:self.rateControl.bottomAnchor constant:24],
        
        [self.muteBtn.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.muteBtn.topAnchor constraintEqualToAnchor:volumeTitle.bottomAnchor constant:12],
        [self.muteBtn.widthAnchor constraintEqualToConstant:36],
        [self.muteBtn.heightAnchor constraintEqualToConstant:36],
        
        [self.volumeSlider.leadingAnchor constraintEqualToAnchor:self.muteBtn.trailingAnchor constant:12],
        [self.volumeSlider.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.volumeSlider.centerYAnchor constraintEqualToAnchor:self.muteBtn.centerYAnchor],
        
        // Extra Features Row
        [extraStack.topAnchor constraintEqualToAnchor:self.volumeSlider.bottomAnchor constant:28],
        [extraStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [extraStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [extraStack.heightAnchor constraintEqualToConstant:48],
        [extraStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-30]
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
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
    [btn setImage:[UIImage systemImageNamed:icon withConfiguration:config] forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@" %@", title] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    btn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    btn.layer.cornerRadius = 12;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

#pragma mark - State Sync

- (void)handleTVOSStateUpdated:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) return;
    
    NSNumber *currentTime = userInfo[HSBRemotePayloadKeyCurrentTime];
    NSNumber *duration = userInfo[HSBRemotePayloadKeyDuration];
    NSNumber *playbackState = userInfo[HSBRemotePayloadKeyPlaybackState];
    NSNumber *volume = userInfo[HSBRemotePayloadKeyVolume];
    NSNumber *muted = userInfo[HSBRemotePayloadKeyMuted];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (duration && [duration doubleValue] > 0) {
            self.currentDuration = [duration doubleValue];
            self.durationLabel.text = [self formatTime:self.currentDuration];
            
            if (currentTime && !self.isDraggingSlider) {
                double cur = [currentTime doubleValue];
                self.currentTimeLabel.text = [self formatTime:cur];
                self.progressSlider.value = (float)(cur / self.currentDuration);
            }
        }
        
        if (playbackState != nil) {
            self.isPlaying = [playbackState boolValue];
            UIImageSymbolConfiguration *bigConfig = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightBold];
            NSString *icon = self.isPlaying ? @"pause.circle.fill" : @"play.circle.fill";
            [self.playPauseBtn setImage:[UIImage systemImageNamed:icon withConfiguration:bigConfig] forState:UIControlStateNormal];
        }

        if (volume != nil && !self.isDraggingVolume) {
            self.volumeSlider.value = MAX(0.0f, MIN(1.0f, volume.floatValue));
        }

        if (muted != nil) {
            self.isMuted = muted.boolValue;
            UIImageSymbolConfiguration *muteConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
            NSString *icon = self.isMuted ? @"speaker.slash.fill" : @"speaker.wave.2.fill";
            [self.muteBtn setImage:[UIImage systemImageNamed:icon withConfiguration:muteConfig] forState:UIControlStateNormal];
            self.muteBtn.tintColor = self.isMuted ? [UIColor systemRedColor] : [UIColor whiteColor];
        }
    });
}

- (NSString *)formatTime:(NSTimeInterval)timeInSeconds {
    if (isnan(timeInSeconds) || isinf(timeInSeconds) || timeInSeconds < 0) {
        return @"00:00";
    }
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

#pragma mark - Actions

- (void)togglePlayPause {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    
    self.isPlaying = !self.isPlaying;
    UIImageSymbolConfiguration *bigConfig = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightBold];
    NSString *icon = self.isPlaying ? @"pause.circle.fill" : @"play.circle.fill";
    [self.playPauseBtn setImage:[UIImage systemImageNamed:icon withConfiguration:bigConfig] forState:UIControlStateNormal];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: self.isPlaying ? (id)HSBRemoteSimulateActionPlay : (id)HSBRemoteSimulateActionPause});
    }
}

- (void)seekBackward {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionSeekRelative, HSBRemotePayloadKeyValue: @(-10)});
    }
}

- (void)seekForward {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionSeekRelative, HSBRemotePayloadKeyValue: @(10)});
    }
}

- (void)sliderChanged:(UISlider *)slider {
    self.isDraggingSlider = YES;
    if (self.currentDuration > 0) {
        NSTimeInterval previewTime = slider.value * self.currentDuration;
        self.currentTimeLabel.text = [self formatTime:previewTime];
    }
}

- (void)sliderEnded:(UISlider *)slider {
    self.isDraggingSlider = NO;
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionSeekPercent, HSBRemotePayloadKeyValue: @(slider.value)});
    }
}

- (void)rateChanged:(UISegmentedControl *)seg {
    NSArray *rates = @[@0.5, @0.75, @1.0, @1.25, @1.5, @2.0];
    NSNumber *rate = rates[seg.selectedSegmentIndex];
    
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionSetRate, HSBRemotePayloadKeyValue: rate});
    }
}

- (void)volumeUp {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionVolumeUp});
    }
    self.volumeSlider.value = MIN(1.0, self.volumeSlider.value + 0.05);
}

- (void)volumeDown {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionVolumeDown});
    }
    self.volumeSlider.value = MAX(0.0, self.volumeSlider.value - 0.05);
}

- (void)toggleMute {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    
    self.isMuted = !self.isMuted;
    UIImageSymbolConfiguration *muteConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    NSString *icon = self.isMuted ? @"speaker.slash.fill" : @"speaker.wave.2.fill";
    [self.muteBtn setImage:[UIImage systemImageNamed:icon withConfiguration:muteConfig] forState:UIControlStateNormal];
    self.muteBtn.tintColor = self.isMuted ? [UIColor systemRedColor] : [UIColor whiteColor];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionToggleMute});
    }
}

- (void)volumeSliderChanged:(UISlider *)slider {
    self.isDraggingVolume = YES;
}

- (void)volumeSliderEnded:(UISlider *)slider {
    self.isDraggingVolume = NO;
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{
            HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionSetVolume,
            HSBRemotePayloadKeyVolume: @(slider.value)
        });
    }
}

- (void)switchAudioTrack {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionSwitchAudioTrack});
    }
}

- (void)switchSubtitleTrack {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionToggleSubtitle});
    }
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    self.playPauseBtn.tintColor = palette.primaryColor;
    self.progressSlider.minimumTrackTintColor = palette.primaryColor;
    self.volumeSlider.minimumTrackTintColor = palette.primaryColor;
    self.rateControl.selectedSegmentTintColor = palette.primaryColor;
    self.audioTrackBtn.tintColor = palette.primaryColor;
    self.subtitleBtn.tintColor = palette.primaryColor;
    
    if (@available(iOS 13.0, *)) {
        [self.rateControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.6]} forState:UIControlStateNormal];
        [self.rateControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    }
}

@end
