//
//  HSBBrowserTouchpadView.m
//  HSBWatchCompanion
//

#import "HSBBrowserTouchpadView.h"
#import "HSBTVOSConnectionConstants.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

static NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

#pragma mark - Custom Four-Finger Drag Gesture

@interface FourFingerDragGestureRecognizer : UIGestureRecognizer
@property (nonatomic, assign) CGPoint lastCenter;
@property (nonatomic, assign) CGPoint currentDelta;
@end

@implementation FourFingerDragGestureRecognizer

- (CGPoint)centerOfTouches:(NSSet<UITouch *> *)touches inView:(UIView *)view {
    CGFloat x = 0, y = 0;
    for (UITouch *t in touches) {
        CGPoint p = [t locationInView:view];
        x += p.x;
        y += p.y;
    }
    return CGPointMake(x / touches.count, y / touches.count);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSUInteger total = event.allTouches.count;
    if (total == 4) {
        self.lastCenter = [self centerOfTouches:event.allTouches inView:self.view];
        self.currentDelta = CGPointZero;
        self.state = UIGestureRecognizerStateBegan;
    } else if (total > 4) {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.state != UIGestureRecognizerStateBegan &&
        self.state != UIGestureRecognizerStateChanged) return;
    CGPoint newCenter = [self centerOfTouches:event.allTouches inView:self.view];
    self.currentDelta = CGPointMake(newCenter.x - self.lastCenter.x,
                                    newCenter.y - self.lastCenter.y);
    self.lastCenter = newCenter;
    self.state = UIGestureRecognizerStateChanged;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.state == UIGestureRecognizerStateBegan ||
        self.state == UIGestureRecognizerStateChanged) {
        self.state = UIGestureRecognizerStateEnded;
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.state = UIGestureRecognizerStateCancelled;
}

@end

#pragma mark - HSBBrowserTouchpadView Implementation

@interface HSBBrowserTouchpadView () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UILabel *trackpadStatusLabel;
@property (nonatomic, strong) UIButton *aiCancelBtn;
@property (nonatomic, assign) CFTimeInterval lastPanSendTime;
@property (nonatomic, assign) CFTimeInterval lastScrollSendTime;
@property (nonatomic, assign) BOOL isDragging;

@end

@implementation HSBBrowserTouchpadView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
        [self setupGestures];
    }
    return self;
}

- (void)setupView {
    self.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.layer.cornerRadius = 24;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor separatorColor].CGColor;
    
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.05;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8;
    
    UILabel *trackpadHint = [[UILabel alloc] init];
    trackpadHint.text = L(@"1-Finger: Move | 2-Fingers: Scroll/Tap | 3-Tap: Force Click | 4-Fingers: Drag",
                          @"单指移动 · 双指滚动/触控点击 · 三指强力点击 · 四指拖动");
    trackpadHint.numberOfLines = 0;
    trackpadHint.textAlignment = NSTextAlignmentCenter;
    trackpadHint.textColor = [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.5];
    trackpadHint.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    trackpadHint.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:trackpadHint];
    
    self.trackpadStatusLabel = [[UILabel alloc] init];
    self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
    self.trackpadStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.trackpadStatusLabel.textColor = [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.4];
    self.trackpadStatusLabel.font = [UIFont systemFontOfSize:42 weight:UIFontWeightUltraLight];
    self.trackpadStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.trackpadStatusLabel];
    
    self.aiCancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.aiCancelBtn setTitle:L(@"Cancel Inference", @"取消 AI 推理") forState:UIControlStateNormal];
    [self.aiCancelBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    self.aiCancelBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    self.aiCancelBtn.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.12];
    self.aiCancelBtn.layer.cornerRadius = 14;
    self.aiCancelBtn.layer.borderWidth = 1.0;
    self.aiCancelBtn.layer.borderColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.3].CGColor;
    self.aiCancelBtn.hidden = YES;
    [self.aiCancelBtn addTarget:self action:@selector(handleCancelAIClick) forControlEvents:UIControlEventTouchUpInside];
    self.aiCancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.aiCancelBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [trackpadHint.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-20],
        [trackpadHint.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [trackpadHint.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        
        [self.trackpadStatusLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.trackpadStatusLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        
        [self.aiCancelBtn.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.aiCancelBtn.topAnchor constraintEqualToAnchor:self.trackpadStatusLabel.bottomAnchor constant:12],
        [self.aiCancelBtn.widthAnchor constraintEqualToConstant:120],
        [self.aiCancelBtn.heightAnchor constraintEqualToConstant:28]
    ]];
}

- (void)setupGestures {
    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTripleTap:)];
    tripleTap.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:tripleTap];
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTouchesRequired = 2;
    [doubleTap requireGestureRecognizerToFail:tripleTap];
    [self addGestureRecognizer:doubleTap];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTouchesRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [singleTap requireGestureRecognizerToFail:tripleTap];
    [self addGestureRecognizer:singleTap];
    
    UIPanGestureRecognizer *singlePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSinglePan:)];
    singlePan.minimumNumberOfTouches = 1;
    singlePan.maximumNumberOfTouches = 1;
    singlePan.delegate = self;
    [self addGestureRecognizer:singlePan];
    
    UIPanGestureRecognizer *doublePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoublePan:)];
    doublePan.minimumNumberOfTouches = 2;
    doublePan.maximumNumberOfTouches = 2;
    [self addGestureRecognizer:doublePan];
    
    FourFingerDragGestureRecognizer *fourFingerDrag = [[FourFingerDragGestureRecognizer alloc] initWithTarget:self action:@selector(handleFourFingerDrag:)];
    [self addGestureRecognizer:fourFingerDrag];
}

- (BOOL)isTargetConnected {
    if (self.checkConnection) {
        return self.checkConnection();
    }
    return YES;
}

- (void)handleSingleTap:(UITapGestureRecognizer *)tap {
    if (tap.state == UIGestureRecognizerStateEnded) {
        if (![self isTargetConnected]) return;
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [hap impactOccurred];
        
        [UIView animateWithDuration:0.1 animations:^{ self.alpha = 0.5; }
                         completion:^(BOOL f) { [UIView animateWithDuration:0.15 animations:^{ self.alpha = 1.0; }]; }];
        
        self.trackpadStatusLabel.text = L(@"\U0001F5B1 Click", @"\U0001F5B1 点击");
        if (self.onTap) {
            self.onTap(1);
        }
        [self restoreReadyAfterDelay:1.0];
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)tap {
    if (tap.state == UIGestureRecognizerStateEnded) {
        if (![self isTargetConnected]) return;
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [hap impactOccurred];
        
        [UIView animateWithDuration:0.08 animations:^{ self.alpha = 0.6; }
                         completion:^(BOOL f) { [UIView animateWithDuration:0.12 animations:^{ self.alpha = 1.0; }]; }];
        
        self.trackpadStatusLabel.text = L(@"\U0001F44C Touch Click", @"\U0001F44C 触控点击");
        if (self.onTap) {
            self.onTap(3); // 3 = WebViewOpTypeTouch
        }
        [self restoreReadyAfterDelay:1.0];
    }
}

- (void)handleTripleTap:(UITapGestureRecognizer *)tap {
    if (tap.state == UIGestureRecognizerStateEnded) {
        if (![self isTargetConnected]) return;
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [hap impactOccurred];
        
        self.trackpadStatusLabel.text = L(@"Force Click", @"强力点击");
        if (self.onTap) {
            self.onTap(5); // 5 = WebViewOpTypeForceClick
        }
        [self restoreReadyAfterDelay:1.0];
    }
}

- (void)handleSinglePan:(UIPanGestureRecognizer *)pan {
    if (![self isTargetConnected]) return;
    if (pan.numberOfTouches != 1 && pan.state != UIGestureRecognizerStateEnded && pan.state != UIGestureRecognizerStateCancelled) return;
    if (self.isDragging) return;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        [pan setTranslation:CGPointZero inView:self];
        return;
    }
    
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastPanSendTime < 0.016) { return; }
    self.lastPanSendTime = now;
    
    if (pan.state == UIGestureRecognizerStateChanged) {
        static const CGFloat kPanScale = 5.5;
        CGPoint translation = [pan translationInView:self];
        CGFloat dx = translation.x * kPanScale;
        CGFloat dy = translation.y * kPanScale;
        [pan setTranslation:CGPointZero inView:self];
        
        if (fabs(dx) > 0.1 || fabs(dy) > 0.1) {
            if (self.onPan) {
                self.onPan(dx, dy);
            }
            self.trackpadStatusLabel.text = L(@"Moving", @"移动");
        }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
    }
}

- (void)handleDoublePan:(UIPanGestureRecognizer *)pan {
    if (![self isTargetConnected]) return;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        [pan setTranslation:CGPointZero inView:self];
        self.trackpadStatusLabel.text = L(@"Scrolling", @"滚动");
        return;
    }
    
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastScrollSendTime < 0.025) { return; }
    self.lastScrollSendTime = now;
    
    if (pan.state == UIGestureRecognizerStateChanged) {
        static const CGFloat kScrollScale = 3.0;
        CGPoint translation = [pan translationInView:self];
        CGFloat dx = -translation.x * kScrollScale;
        CGFloat dy = -translation.y * kScrollScale;
        [pan setTranslation:CGPointZero inView:self];
        
        if (self.onScroll) {
            self.onScroll(dx, dy);
        }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
    }
}

- (void)handleFourFingerDrag:(FourFingerDragGestureRecognizer *)pan {
    if (![self isTargetConnected]) return;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.isDragging = YES;
        self.trackpadStatusLabel.text = L(@"Dragging", @"拖动中");
        self.layer.borderColor = [UIColor systemBlueColor].CGColor;
        self.layer.borderWidth = 2.0;
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [hap impactOccurred];
        
        if (self.onDrag) {
            self.onDrag(HSBRemoteDrawTypeBegan, 0, 0);
        }
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CFTimeInterval now = CACurrentMediaTime();
        if (now - self.lastPanSendTime < 0.016) { return; }
        self.lastPanSendTime = now;
        
        static const CGFloat kDragScale = 5.5;
        CGFloat dx = pan.currentDelta.x * kDragScale;
        CGFloat dy = pan.currentDelta.y * kDragScale;
        
        if (fabs(dx) > 0.1 || fabs(dy) > 0.1) {
            if (self.onDrag) {
                self.onDrag(HSBRemoteDrawTypeMoved, dx, dy);
            }
        }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        self.isDragging = NO;
        self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
        self.layer.borderColor = [UIColor separatorColor].CGColor;
        self.layer.borderWidth = 1.0;
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [hap impactOccurred];
        
        if (self.onDrag) {
            self.onDrag(HSBRemoteDrawTypeEnded, 0, 0);
        }
    }
}

- (void)handleCancelAIClick {
    if (self.onCancelAI) {
        self.onCancelAI();
    }
}

- (void)setStatusText:(NSString *)text {
    self.trackpadStatusLabel.text = text;
}

- (void)setStatusText:(NSString *)text restoreReadyAfter:(NSTimeInterval)delay {
    self.trackpadStatusLabel.text = text;
    [self restoreReadyAfterDelay:delay];
}

- (void)restoreReadyAfterDelay:(NSTimeInterval)delay {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!weakSelf.isDragging) {
            weakSelf.trackpadStatusLabel.text = L(@"Ready", @"就绪");
        }
    });
}

- (void)setAICancelButtonHidden:(BOOL)hidden {
    self.aiCancelBtn.hidden = hidden;
}

- (NSString *)currentStatusText {
    return self.trackpadStatusLabel.text ?: @"";
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

@end
