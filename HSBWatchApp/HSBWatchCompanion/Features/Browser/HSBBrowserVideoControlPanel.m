//
//  HSBBrowserVideoControlPanel.m
//  HSBWatchCompanion
//

#import "HSBBrowserVideoControlPanel.h"
#import "HSBThemeManager.h"
#import "HSBWatchCompanion-Swift.h"

static NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBBrowserVideoControlPanel ()

@property (nonatomic, strong) UIButton *openPlayerBtn;
@property (nonatomic, strong) UIButton *closePlayerBtn;
@property (nonatomic, strong) UISlider *videoSlider;
@property (nonatomic, strong) UILabel *videoPercentLabel;

@end

@implementation HSBBrowserVideoControlPanel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

- (void)setupView {
    UIStackView *videoPanel = [[UIStackView alloc] init];
    videoPanel.axis = UILayoutConstraintAxisVertical;
    videoPanel.spacing = 12;
    videoPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:videoPanel];
    
    // 1. Player Button Row
    UIStackView *playerBtnRow = [[UIStackView alloc] init];
    playerBtnRow.axis = UILayoutConstraintAxisHorizontal;
    playerBtnRow.distribution = UIStackViewDistributionFillEqually;
    playerBtnRow.spacing = 12;
    playerBtnRow.translatesAutoresizingMaskIntoConstraints = NO;
    [videoPanel addArrangedSubview:playerBtnRow];
    
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    self.openPlayerBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.openPlayerBtn.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
    self.openPlayerBtn.layer.cornerRadius = 12;
    [self.openPlayerBtn setTitle:L(@"Open Video Player", @"打开播放器") forState:UIControlStateNormal];
    [self.openPlayerBtn setTitleColor:palette.primaryColor forState:UIControlStateNormal];
    [self.openPlayerBtn setImage:[UIImage systemImageNamed:@"play.rectangle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    self.openPlayerBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    self.openPlayerBtn.tintColor = palette.primaryColor;
    self.openPlayerBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
    self.openPlayerBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
    self.openPlayerBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.openPlayerBtn.heightAnchor constraintEqualToConstant:46].active = YES;
    [self.openPlayerBtn addTarget:self action:@selector(handleOpenPlayer) forControlEvents:UIControlEventTouchUpInside];
    [playerBtnRow addArrangedSubview:self.openPlayerBtn];
    
    self.closePlayerBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closePlayerBtn.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
    self.closePlayerBtn.layer.cornerRadius = 12;
    [self.closePlayerBtn setTitle:L(@"Close Player", @"关闭播放器") forState:UIControlStateNormal];
    [self.closePlayerBtn setTitleColor:palette.primaryColor forState:UIControlStateNormal];
    [self.closePlayerBtn setImage:[UIImage systemImageNamed:@"xmark.rectangle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    self.closePlayerBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    self.closePlayerBtn.tintColor = palette.primaryColor;
    self.closePlayerBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
    self.closePlayerBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
    self.closePlayerBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closePlayerBtn.heightAnchor constraintEqualToConstant:46].active = YES;
    [self.closePlayerBtn addTarget:self action:@selector(handleClosePlayer) forControlEvents:UIControlEventTouchUpInside];
    [playerBtnRow addArrangedSubview:self.closePlayerBtn];
    
    // 2. Video Slider Row
    UIStackView *sliderRow = [[UIStackView alloc] init];
    sliderRow.axis = UILayoutConstraintAxisHorizontal;
    sliderRow.spacing = 10;
    sliderRow.alignment = UIStackViewAlignmentCenter;
    sliderRow.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIImageView *sliderIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"video.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    sliderIcon.tintColor = [UIColor secondaryLabelColor];
    sliderIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [sliderIcon.widthAnchor constraintEqualToConstant:20].active = YES;
    [sliderIcon.heightAnchor constraintEqualToConstant:20].active = YES;
    [sliderRow addArrangedSubview:sliderIcon];
    
    self.videoSlider = [[UISlider alloc] init];
    self.videoSlider.minimumValue = 0.0;
    self.videoSlider.maximumValue = 1.0;
    self.videoSlider.value = 0.5;
    self.videoSlider.minimumTrackTintColor = palette.primaryColor;
    [self.videoSlider addTarget:self action:@selector(videoSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.videoSlider addTarget:self action:@selector(videoSliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    self.videoSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [sliderRow addArrangedSubview:self.videoSlider];
    
    self.videoPercentLabel = [[UILabel alloc] init];
    self.videoPercentLabel.text = @"50%";
    self.videoPercentLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.videoPercentLabel.textColor = [UIColor secondaryLabelColor];
    self.videoPercentLabel.textAlignment = NSTextAlignmentRight;
    self.videoPercentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.videoPercentLabel.widthAnchor constraintEqualToConstant:40].active = YES;
    [sliderRow addArrangedSubview:self.videoPercentLabel];
    
    [videoPanel addArrangedSubview:sliderRow];
    
    [NSLayoutConstraint activateConstraints:@[
        [videoPanel.topAnchor constraintEqualToAnchor:self.topAnchor],
        [videoPanel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [videoPanel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [videoPanel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

- (void)handleOpenPlayer {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    if (self.onOpenPlayer) {
        self.onOpenPlayer();
    }
}

- (void)handleClosePlayer {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    if (self.onClosePlayer) {
        self.onClosePlayer();
    }
}

- (void)videoSliderChanged:(UISlider *)slider {
    self.videoPercentLabel.text = [NSString stringWithFormat:@"%.0f%%", slider.value * 100];
}

- (void)videoSliderEnded:(UISlider *)slider {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if (self.onSeekPercent) {
        self.onSeekPercent(slider.value);
    }
}

- (void)applyThemeStyle {
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    if (self.openPlayerBtn) {
        self.openPlayerBtn.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
        [self.openPlayerBtn setTitleColor:palette.primaryColor forState:UIControlStateNormal];
        [self.openPlayerBtn setTintColor:palette.primaryColor];
    }
    if (self.closePlayerBtn) {
        self.closePlayerBtn.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
        [self.closePlayerBtn setTitleColor:palette.primaryColor forState:UIControlStateNormal];
        [self.closePlayerBtn setTintColor:palette.primaryColor];
    }
    if (self.videoSlider) {
        self.videoSlider.minimumTrackTintColor = palette.primaryColor;
    }
}

@end
