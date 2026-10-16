//
//  HSBBrowserSpeechAssistant.m
//  HSBWatchCompanion
//

#import "HSBBrowserSpeechAssistant.h"
#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>
#import "HSBLocalLLMManager.h"
#import "HSBTVOSConnectionConstants.h"
#import "HSBBrowserAIEngine.h"

static NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBBrowserSpeechAssistant ()

@property (nonatomic, weak) UIView *containerView;
@property (nonatomic, strong) UIButton *aiBtn;
@property (nonatomic, assign) BOOL isAIButtonPressed;

@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, copy) NSString *recognizedSpeechText;

@property (nonatomic, strong) UIView *speechPanel;
@property (nonatomic, strong) UILabel *speechStatusLabel;
@property (nonatomic, strong) UILabel *speechResultLabel;

@property (nonatomic, strong) NSTimer *aiTimeoutTimer;
@property (nonatomic, assign) BOOL isAIInferenceCancelled;

@end

@implementation HSBBrowserSpeechAssistant

- (UIButton *)aiFloatingButton {
    return self.aiBtn;
}

- (instancetype)initWithContainerView:(UIView *)containerView {
    self = [super init];
    if (self) {
        _containerView = containerView;
        [self setupAIButton];
        [self setupSpeechPanel];
    }
    return self;
}

- (void)setupAIButton {
    self.aiBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.aiBtn setImage:[UIImage systemImageNamed:@"sparkles" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    self.aiBtn.tintColor = [UIColor whiteColor];
    self.aiBtn.backgroundColor = [UIColor systemPurpleColor];
    self.aiBtn.layer.cornerRadius = 28;
    self.aiBtn.clipsToBounds = NO;
    
    self.aiBtn.layer.shadowColor = [UIColor systemPurpleColor].CGColor;
    self.aiBtn.layer.shadowOffset = CGSizeMake(0, 4);
    self.aiBtn.layer.shadowOpacity = 0.4;
    self.aiBtn.layer.shadowRadius = 8;
    
    [self.aiBtn addTarget:self action:@selector(aiButtonTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.aiBtn addTarget:self action:@selector(aiButtonTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    self.aiBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.aiBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.aiBtn.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-24],
        [self.aiBtn.bottomAnchor constraintEqualToAnchor:self.containerView.safeAreaLayoutGuide.bottomAnchor constant:-90],
        [self.aiBtn.widthAnchor constraintEqualToConstant:56],
        [self.aiBtn.heightAnchor constraintEqualToConstant:56]
    ]];
}

- (void)setupSpeechPanel {
    self.speechPanel = [[UIView alloc] init];
    self.speechPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.speechPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    self.speechPanel.layer.cornerRadius = 20;
    self.speechPanel.layer.borderWidth = 1.5;
    self.speechPanel.layer.borderColor = [[UIColor systemPurpleColor] colorWithAlphaComponent:0.4].CGColor;
    
    self.speechPanel.layer.shadowColor = [UIColor systemPurpleColor].CGColor;
    self.speechPanel.layer.shadowOpacity = 0.25;
    self.speechPanel.layer.shadowOffset = CGSizeMake(0, 8);
    self.speechPanel.layer.shadowRadius = 16;
    self.speechPanel.hidden = YES;
    [self.containerView addSubview:self.speechPanel];
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.speechPanel.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = 20;
    blurView.clipsToBounds = YES;
    [self.speechPanel addSubview:blurView];
    
    UIImageView *micIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform.and.mic" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIFontWeightSemibold]]];
    micIcon.tintColor = [UIColor systemPurpleColor];
    micIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.speechPanel addSubview:micIcon];
    
    self.speechStatusLabel = [[UILabel alloc] init];
    self.speechStatusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.speechStatusLabel.textColor = [UIColor systemPurpleColor];
    self.speechStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.speechPanel addSubview:self.speechStatusLabel];
    
    self.speechResultLabel = [[UILabel alloc] init];
    self.speechResultLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.speechResultLabel.textColor = [UIColor whiteColor];
    self.speechResultLabel.numberOfLines = 2;
    self.speechResultLabel.textAlignment = NSTextAlignmentLeft;
    self.speechResultLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.speechPanel addSubview:self.speechResultLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.speechPanel.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-24],
        [self.speechPanel.bottomAnchor constraintEqualToAnchor:self.aiBtn.topAnchor constant:-12],
        [self.speechPanel.widthAnchor constraintEqualToConstant:220],
        [self.speechPanel.heightAnchor constraintEqualToConstant:100],
        
        [micIcon.leadingAnchor constraintEqualToAnchor:self.speechPanel.leadingAnchor constant:14],
        [micIcon.topAnchor constraintEqualToAnchor:self.speechPanel.topAnchor constant:12],
        [micIcon.widthAnchor constraintEqualToConstant:16],
        [micIcon.heightAnchor constraintEqualToConstant:16],
        
        [self.speechStatusLabel.leadingAnchor constraintEqualToAnchor:micIcon.trailingAnchor constant:6],
        [self.speechStatusLabel.centerYAnchor constraintEqualToAnchor:micIcon.centerYAnchor],
        
        [self.speechResultLabel.leadingAnchor constraintEqualToAnchor:self.speechPanel.leadingAnchor constant:14],
        [self.speechResultLabel.trailingAnchor constraintEqualToAnchor:self.speechPanel.trailingAnchor constant:-14],
        [self.speechResultLabel.topAnchor constraintEqualToAnchor:micIcon.bottomAnchor constant:10],
        [self.speechResultLabel.bottomAnchor constraintEqualToAnchor:self.speechPanel.bottomAnchor constant:-12]
    ]];
    
    [self.containerView bringSubviewToFront:self.speechPanel];
    [self.containerView bringSubviewToFront:self.aiBtn];
}

- (void)aiButtonTouchDown {
    self.isAIButtonPressed = YES;
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [hap impactOccurred];
    [self startRecordingAndRecognition];
}

- (void)aiButtonTouchUp {
    if (!self.isAIButtonPressed) return;
    self.isAIButtonPressed = NO;
    [self stopRecordingAndRecognition];
}

- (void)startRecordingAndRecognition {
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (granted) {
                            [self performRecordingStart];
                        } else {
                            [self showSpeechAlertError:L(@"Microphone permission denied.", @"麦克风权限未开启")];
                        }
                    });
                }];
            } else {
                [self showSpeechAlertError:L(@"Speech recognition permission denied.", @"语音识别权限未开启")];
            }
        });
    }];
}

- (void)performRecordingStart {
    if (!self.isAIButtonPressed) return;
    
    if (self.recognitionTask) {
        [self.recognitionTask cancel];
        self.recognitionTask = nil;
    }
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [audioSession setCategory:AVAudioSessionCategoryRecord mode:AVAudioSessionModeMeasurement options:AVAudioSessionCategoryOptionDuckOthers error:&error];
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    
    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    self.audioEngine = [[AVAudioEngine alloc] init];
    
    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    self.recognitionRequest.shouldReportPartialResults = YES;
    
    NSString *localeStr = L(@"en-US", @"zh-CN");
    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:localeStr]];
    
    __weak typeof(self) weakSelf = self;
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable taskError) {
        if (result) {
            NSString *bestString = result.bestTranscription.formattedString;
            weakSelf.recognizedSpeechText = bestString;
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.speechResultLabel.text = bestString;
            });
        }
        
        if (taskError || (result && result.isFinal)) {
            [weakSelf.audioEngine stop];
            [inputNode removeTapOnBus:0];
            weakSelf.recognitionRequest = nil;
            weakSelf.recognitionTask = nil;
        }
    }];
    
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [weakSelf.recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    [self.audioEngine prepare];
    [self.audioEngine startAndReturnError:&error];
    
    self.recognizedSpeechText = @"";
    [self showSpeechPanel];
}

- (void)stopRecordingAndRecognition {
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        [self.recognitionRequest endAudio];
        [self hideSpeechPanel];
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [hap impactOccurred];
        
        NSString *trimmedText = [self.recognizedSpeechText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *cleanText = [[trimmedText stringByReplacingOccurrencesOfString:@"。" withString:@""] stringByReplacingOccurrencesOfString:@"，" withString:@""];
        cleanText = [[cleanText stringByReplacingOccurrencesOfString:@"！" withString:@""] stringByReplacingOccurrencesOfString:@"？" withString:@""];
        
        if (cleanText.length > 0) {
            NSDictionary<NSString *, NSString *> *voiceCommands = @{
                @"往上": HSBRemoteSimulateActionUp,
                @"往下": HSBRemoteSimulateActionDown,
                @"往左": HSBRemoteSimulateActionLeft,
                @"往右": HSBRemoteSimulateActionRight,
                @"返回": HSBRemoteSimulateActionMenu,
                @"暂停": HSBRemoteSimulateActionPause,
                @"播放": HSBRemoteSimulateActionPlay,
                @"打开播放器": HSBRemoteSimulateActionOpenPlayer
            };
            
            NSString *matchedAction = nil;
            for (NSString *key in voiceCommands) {
                if ([cleanText containsString:key]) {
                    matchedAction = voiceCommands[key];
                    break;
                }
            }
            
            if (matchedAction) {
                if (self.onSendAction) {
                    self.onSendAction(matchedAction);
                }
                if (self.onShowToast) {
                    self.onShowToast([NSString stringWithFormat:L(@"已发送指令: %@", @"Sent command: %@"), cleanText]);
                }
                return;
            }
            
            [self processAIRequest:trimmedText type:2];
        }
    }
}

- (void)showSpeechPanel {
    self.speechPanel.hidden = NO;
    self.speechPanel.alpha = 0.0;
    self.speechPanel.transform = CGAffineTransformMakeTranslation(0, 30);
    self.speechStatusLabel.text = L(@"Listening...", @"正在倾听...");
    self.speechResultLabel.text = L(@"Speak your instruction...", @"请说出您的操作指令...");
    
    [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.speechPanel.alpha = 1.0;
        self.speechPanel.transform = CGAffineTransformIdentity;
    } completion:nil];
    
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.duration = 1.0;
    pulse.fromValue = @(0.95);
    pulse.toValue = @(1.05);
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    pulse.autoreverses = YES;
    pulse.repeatCount = INFINITY;
    [self.speechPanel.layer addAnimation:pulse forKey:@"pulseAnimation"];
}

- (void)hideSpeechPanel {
    [UIView animateWithDuration:0.25 animations:^{
        self.speechPanel.alpha = 0.0;
        self.speechPanel.transform = CGAffineTransformMakeTranslation(0, 30);
    } completion:^(BOOL finished) {
        self.speechPanel.hidden = YES;
        [self.speechPanel.layer removeAnimationForKey:@"pulseAnimation"];
    }];
}

- (void)showSpeechAlertError:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Voice Control Error", @"语音控制失败")
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"OK", @"好的") style:UIAlertActionStyleDefault handler:nil]];
    if (self.onPresentAlert) {
        self.onPresentAlert(alert);
    }
}

- (void)processAIRequest:(NSString *)text type:(NSInteger)type {
    if (text.length == 0) return;
    self.isAIInferenceCancelled = NO;
    
    if (self.aiTimeoutTimer) {
        [self.aiTimeoutTimer invalidate];
        self.aiTimeoutTimer = nil;
    }
    self.aiTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(handleAIInferenceTimeout) userInfo:nil repeats:NO];
    
    if (self.onStatusUpdate) {
        self.onStatusUpdate(L(@"AI Thinking...", @"AI 思考中..."), YES);
    }
    
    __weak typeof(self) weakSelf = self;
    [HSBBrowserAIEngine processAIRequest:text type:type onStreamUpdate:^(NSString * _Nonnull partialText) {
        if (weakSelf.isAIInferenceCancelled) return;
        if (weakSelf.onStatusUpdate) {
            weakSelf.onStatusUpdate([NSString stringWithFormat:@"%@ (%lu)", L(@"AI Thinking...", @"AI 思考中..."), (unsigned long)partialText.length], YES);
        }
    } completion:^(NSDictionary * _Nonnull payload, NSString * _Nonnull rawResponse, BOOL isTranslation) {
        if (weakSelf.isAIInferenceCancelled) return;
        
        if (weakSelf.aiTimeoutTimer) {
            [weakSelf.aiTimeoutTimer invalidate];
            weakSelf.aiTimeoutTimer = nil;
        }
        
        if (weakSelf.onStatusUpdate) {
            weakSelf.onStatusUpdate(L(@"AI Done", @"AI 处理完成"), NO);
        }
        
        if (isTranslation) {
            UIAlertController *res = [UIAlertController alertControllerWithTitle:L(@"Translation Result", @"翻译结果")
                                                                         message:rawResponse
                                                                  preferredStyle:UIAlertControllerStyleAlert];
            [res addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            if (weakSelf.onPresentAlert) {
                weakSelf.onPresentAlert(res);
            }
            if (weakSelf.onSendPayload) {
                weakSelf.onSendPayload(payload);
            }
        } else {
            if (weakSelf.onSendPayload) {
                weakSelf.onSendPayload(payload);
            }
        }
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [hap impactOccurred];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (weakSelf.onStatusUpdate) {
                weakSelf.onStatusUpdate(L(@"Ready", @"就绪"), NO);
            }
        });
    }];
}

- (void)cancelCurrentAIInference {
    self.isAIInferenceCancelled = YES;
    if (self.aiTimeoutTimer) {
        [self.aiTimeoutTimer invalidate];
        self.aiTimeoutTimer = nil;
    }
    [[HSBLocalLLMManager shared] cancelInference];
    if (self.onStatusUpdate) {
        self.onStatusUpdate(L(@"AI Cancelled", @"AI 已取消"), NO);
    }
    UINotificationFeedbackGenerator *hap = [[UINotificationFeedbackGenerator alloc] init];
    [hap notificationOccurred:UINotificationFeedbackTypeWarning];
    
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.onStatusUpdate) {
            weakSelf.onStatusUpdate(L(@"Ready", @"就绪"), NO);
        }
    });
}

- (void)handleAIInferenceTimeout {
    self.aiTimeoutTimer = nil;
    self.isAIInferenceCancelled = YES;
    [[HSBLocalLLMManager shared] cancelInference];
    if (self.onStatusUpdate) {
        self.onStatusUpdate(L(@"AI Timeout", @"AI 推理超时 (30s)"), NO);
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Inference Timeout", @"AI 推理超时")
                                                                   message:L(@"AI inference has been cancelled because it took longer than 30 seconds.", @"端侧大模型推理超时（已超过 30 秒），已自动为您中止以保护电池寿命。")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"OK", @"好的") style:UIAlertActionStyleDefault handler:nil]];
    if (self.onPresentAlert) {
        self.onPresentAlert(alert);
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.onStatusUpdate) {
            weakSelf.onStatusUpdate(L(@"Ready", @"就绪"), NO);
        }
    });
}

- (void)stopAudioIfRunning {
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        self.recognitionRequest = nil;
        self.recognitionTask = nil;
    }
}

@end
