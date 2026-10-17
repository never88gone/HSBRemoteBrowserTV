//
//  HSBVideoPlayerControlPanelView.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBVideoPlayerControlPanelView : UIView

@property (nonatomic, copy, nullable) void (^onPlayPauseToggled)(void);
@property (nonatomic, copy, nullable) void (^onSeekBackward)(void);
@property (nonatomic, copy, nullable) void (^onSeekForward)(void);
@property (nonatomic, copy, nullable) void (^onSliderChanged)(float value);
@property (nonatomic, copy, nullable) void (^onSliderEnded)(float value);
@property (nonatomic, copy, nullable) void (^onRateChanged)(double rate);
@property (nonatomic, copy, nullable) void (^onToggleMute)(void);
@property (nonatomic, copy, nullable) void (^onVolumeChanged)(float value);
@property (nonatomic, copy, nullable) void (^onVolumeEnded)(float value);
@property (nonatomic, copy, nullable) void (^onSwitchAudioTrack)(void);
@property (nonatomic, copy, nullable) void (^onSwitchSubtitleTrack)(void);

- (void)updatePlayingState:(BOOL)isPlaying;
- (void)updateCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration isSeeking:(BOOL)isSeeking;
- (void)updatePlaybackRate:(double)rate;
- (void)updateVolume:(float)volume isMuted:(BOOL)isMuted;
- (void)applyThemePrimaryColor:(UIColor *)primaryColor;

@end

NS_ASSUME_NONNULL_END
