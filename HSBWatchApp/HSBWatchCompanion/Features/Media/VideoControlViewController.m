//
//  VideoControlViewController.m
//  HSBWatchCompanion
//

#import "VideoControlViewController.h"
#import <UIKit/UIKit.h>
#import "HSBThemeManager.h"
#import "HSBTVOSConnectionManager.h"
#import "HSBPhysicalVolumeListener.h"
#import "HSBVideoPlayerControlPanelView.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface VideoControlViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) HSBVideoPlayerControlPanelView *controlPanelView;

// Playback State
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) NSTimeInterval currentTime;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) double playbackRate;
@property (nonatomic, assign) float volume;
@property (nonatomic, assign) BOOL isMuted;

// UI interaction states
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic, strong) HSBPhysicalVolumeListener *volumeListener;

@end

@implementation VideoControlViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.volumeListener stopListening];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"Video Player", @"全屏播放器");
    
    // Default mock or fallback states
    self.isPlaying = YES;
    self.currentTime = 0;
    self.duration = 0;
    self.playbackRate = 1.0;
    self.volume = 1.0;
    self.isMuted = NO;
    
    [self setupUI];
    [self applyThemeStyle];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTVOSStateUpdated:)
                                                 name:HSBTVOSStateUpdatedNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    __weak typeof(self) weakSelf = self;
    self.volumeListener = [HSBPhysicalVolumeListener sharedListener];
    self.volumeListener.onVolumeUp = ^{
        [weakSelf volumeUp];
    };
    self.volumeListener.onVolumeDown = ^{
        [weakSelf volumeDown];
    };
    [self.volumeListener startListening];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.volumeListener stopListening];
    self.volumeListener.onVolumeUp = nil;
    self.volumeListener.onVolumeDown = nil;
    self.volumeListener = nil;
}

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    
    self.controlPanelView = [[HSBVideoPlayerControlPanelView alloc] init];
    [self.scrollView addSubview:self.controlPanelView];
    
    __weak typeof(self) weakSelf = self;
    self.controlPanelView.onPlayPauseToggled = ^{ [weakSelf togglePlayPause]; };
    self.controlPanelView.onSeekBackward = ^{ [weakSelf seekBackward]; };
    self.controlPanelView.onSeekForward = ^{ [weakSelf seekForward]; };
    self.controlPanelView.onSliderChanged = ^(float value) { [weakSelf handleSliderChanged:value]; };
    self.controlPanelView.onSliderEnded = ^(float value) { [weakSelf handleSliderEnded:value]; };
    self.controlPanelView.onRateChanged = ^(double rate) { [weakSelf handleRateChanged:rate]; };
    self.controlPanelView.onToggleMute = ^{ [weakSelf toggleMute]; };
    self.controlPanelView.onVolumeChanged = ^(float value) { [weakSelf handleVolumeChanged:value]; };
    self.controlPanelView.onVolumeEnded = ^(float value) { [weakSelf handleVolumeEnded:value]; };
    self.controlPanelView.onSwitchAudioTrack = ^{ [weakSelf switchAudioTrack]; };
    self.controlPanelView.onSwitchSubtitleTrack = ^{ [weakSelf switchSubtitleTrack]; };
    
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.controlPanelView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.controlPanelView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.controlPanelView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.controlPanelView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.controlPanelView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];
}

#pragma mark - TV Notification Receiver

- (void)handleTVOSStateUpdated:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (userInfo[@"isPlaying"]) {
            self.isPlaying = [userInfo[@"isPlaying"] boolValue];
            [self.controlPanelView updatePlayingState:self.isPlaying];
        }
        
        if (userInfo[@"duration"]) {
            self.duration = [userInfo[@"duration"] doubleValue];
        }
        
        if (userInfo[@"currentTime"] && !self.isSeeking) {
            self.currentTime = [userInfo[@"currentTime"] doubleValue];
            [self.controlPanelView updateCurrentTime:self.currentTime duration:self.duration isSeeking:self.isSeeking];
        }
        
        if (userInfo[@"playbackRate"]) {
            self.playbackRate = [userInfo[@"playbackRate"] doubleValue];
            [self.controlPanelView updatePlaybackRate:self.playbackRate];
        }
        
        if (userInfo[@"volume"]) {
            self.volume = [userInfo[@"volume"] floatValue];
            self.isMuted = (self.volume <= 0.001);
            [self.controlPanelView updateVolume:self.volume isMuted:self.isMuted];
        }
    });
}

#pragma mark - Transport Actions

- (void)togglePlayPause {
    self.isPlaying = !self.isPlaying;
    [self.controlPanelView updatePlayingState:self.isPlaying];
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = self.isPlaying ? HSBRemoteSimulateActionPlay : HSBRemoteSimulateActionPause;
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)seekBackward {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionSeekBackward;
    payload[HSBRemotePayloadKeyValue] = @10;
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)seekForward {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionSeekForward;
    payload[HSBRemotePayloadKeyValue] = @10;
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)handleSliderChanged:(float)value {
    self.isSeeking = YES;
    if (self.duration > 0) {
        NSTimeInterval previewTime = value * self.duration;
        [self.controlPanelView updateCurrentTime:previewTime duration:self.duration isSeeking:YES];
    }
}

- (void)handleSliderEnded:(float)value {
    self.isSeeking = NO;
    if (self.duration > 0) {
        NSTimeInterval targetTime = value * self.duration;
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionSeekAbsolute;
        payload[HSBRemotePayloadKeyValue] = @(targetTime);
        [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    }
}

- (void)handleRateChanged:(double)rate {
    self.playbackRate = rate;
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionSetRate;
    payload[HSBRemotePayloadKeyValue] = @(rate);
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)volumeUp {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionVolumeUp;
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)volumeDown {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionVolumeDown;
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)toggleMute {
    self.isMuted = !self.isMuted;
    [self.controlPanelView updateVolume:self.volume isMuted:self.isMuted];
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionToggleMute;
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)handleVolumeChanged:(float)value {
    // 实时滑动不做频繁指令下发
}

- (void)handleVolumeEnded:(float)value {
    self.volume = value;
    self.isMuted = (value <= 0.001);
    [self.controlPanelView updateVolume:self.volume isMuted:self.isMuted];
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionSetVolume;
    payload[HSBRemotePayloadKeyValue] = @(value);
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)switchAudioTrack {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionSwitchAudioTrack;
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)switchSubtitleTrack {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionToggleSubtitle;
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *p = [HSBThemeManager shared].currentPalette;
    self.view.backgroundColor = p.backgroundColor;
    [self.controlPanelView applyThemePrimaryColor:p.primaryColor];
}

@end
