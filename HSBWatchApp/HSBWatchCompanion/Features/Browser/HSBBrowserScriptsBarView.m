//
//  HSBBrowserScriptsBarView.m
//  HSBWatchCompanion
//

#import "HSBBrowserScriptsBarView.h"
#import "HSBThemeManager.h"
#import "HSBWatchCompanion-Swift.h"

@interface HSBBrowserScriptsBarView ()

@property (nonatomic, strong) UIScrollView *scriptsScrollView;
@property (nonatomic, strong) UIStackView *scriptsStackView;
@property (nonatomic, copy) NSArray<NSString *> *scriptNames;

@end

@implementation HSBBrowserScriptsBarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

- (void)setupView {
    self.scriptNames = @[
        @"抖音_全屏",
        @"抖音_启动跳转",
        @"抖音_自动登录",
        @"抖音_连播点击",
        @"抖音_高分辨率",
        @"腾讯视频_全屏"
    ];
    
    self.scriptsScrollView = [[UIScrollView alloc] init];
    self.scriptsScrollView.showsHorizontalScrollIndicator = NO;
    self.scriptsScrollView.alwaysBounceHorizontal = YES;
    self.scriptsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.scriptsScrollView];
    
    self.scriptsStackView = [[UIStackView alloc] init];
    self.scriptsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.scriptsStackView.spacing = 8;
    self.scriptsStackView.alignment = UIStackViewAlignmentCenter;
    self.scriptsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scriptsScrollView addSubview:self.scriptsStackView];
    
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    for (NSInteger i = 0; i < self.scriptNames.count; i++) {
        NSString *scriptName = self.scriptNames[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:scriptName forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        btn.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.12];
        [btn setTitleColor:palette.primaryColor forState:UIControlStateNormal];
        btn.layer.cornerRadius = 14;
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        btn.tag = i;
        [btn addTarget:self action:@selector(handleScriptButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [self.scriptsStackView addArrangedSubview:btn];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [self.scriptsScrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.scriptsScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.scriptsScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.scriptsScrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        
        [self.scriptsStackView.topAnchor constraintEqualToAnchor:self.scriptsScrollView.contentLayoutGuide.topAnchor],
        [self.scriptsStackView.bottomAnchor constraintEqualToAnchor:self.scriptsScrollView.contentLayoutGuide.bottomAnchor],
        [self.scriptsStackView.leadingAnchor constraintEqualToAnchor:self.scriptsScrollView.contentLayoutGuide.leadingAnchor constant:20],
        [self.scriptsStackView.trailingAnchor constraintEqualToAnchor:self.scriptsScrollView.contentLayoutGuide.trailingAnchor constant:-20],
        [self.scriptsStackView.heightAnchor constraintEqualToAnchor:self.scriptsScrollView.frameLayoutGuide.heightAnchor]
    ]];
}

- (void)handleScriptButtonTap:(UIButton *)sender {
    if (sender.tag >= self.scriptNames.count) return;
    
    NSString *scriptName = self.scriptNames[sender.tag];
    NSString *path = [[NSBundle mainBundle] pathForResource:scriptName ofType:@"js"];
    if (!path) {
        NSLog(@"[JS Script] Script not found in bundle: %@", scriptName);
        return;
    }
    
    NSError *error = nil;
    NSString *jsContent = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error || jsContent.length == 0) {
        NSLog(@"[JS Script] Failed to read script: %@, error: %@", scriptName, error.localizedDescription);
        return;
    }
    
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            sender.transform = CGAffineTransformIdentity;
        }];
    }];
    
    if (self.onExecuteScript) {
        self.onExecuteScript(scriptName, jsContent);
    }
}

- (void)applyThemeStyle {
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    for (UIView *subview in self.scriptsStackView.arrangedSubviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)subview;
            btn.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.12];
            [btn setTitleColor:palette.primaryColor forState:UIControlStateNormal];
        }
    }
}

@end
