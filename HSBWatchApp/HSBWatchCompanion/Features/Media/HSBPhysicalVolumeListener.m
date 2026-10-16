//
//  HSBPhysicalVolumeListener.m
//  HSBWatchCompanion
//

#import "HSBPhysicalVolumeListener.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>

@interface HSBPhysicalVolumeListener ()
@property (nonatomic, strong) MPVolumeView *hiddenVolumeView;
@property (nonatomic, assign, readwrite) BOOL isListening;
@property (nonatomic, assign) float initialVolume;
@end

@implementation HSBPhysicalVolumeListener

+ (instancetype)sharedListener {
    static HSBPhysicalVolumeListener *listener;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        listener = [[HSBPhysicalVolumeListener alloc] init];
    });
    return listener;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1000, -1000, 1, 1)];
        _hiddenVolumeView.alpha = 0.01;
        UIWindow *keyWindow = [UIApplication sharedApplication].windows.firstObject;
        if (keyWindow) {
            [keyWindow addSubview:_hiddenVolumeView];
        }
    }
    return self;
}

- (void)dealloc {
    [self stopListening];
}

- (void)startListening {
    if (self.isListening) return;
    NSError *err = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:&err];
    self.initialVolume = session.outputVolume;
    [session addObserver:self
              forKeyPath:@"outputVolume"
                 options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                 context:nil];
    self.isListening = YES;
}

- (void)stopListening {
    if (!self.isListening) return;
    @try {
        [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
    } @catch (NSException *exception) {}
    self.isListening = NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"outputVolume"]) {
        float oldVol = [change[NSKeyValueChangeOldKey] floatValue];
        float newVol = [change[NSKeyValueChangeNewKey] floatValue];
        if (newVol > oldVol) {
            if (self.onVolumeUp) {
                self.onVolumeUp();
            }
        } else if (newVol < oldVol) {
            if (self.onVolumeDown) {
                self.onVolumeDown();
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
