#import "HSBLLMResultCardView.h"
#import "HSBThemeManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBLLMResultCardView ()

@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, strong) UIButton *clipboardBtn;

@end

@implementation HSBLLMResultCardView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
    self.layer.cornerRadius = 16;
    self.hidden = YES;
    
    _resultTextView = [[UITextView alloc] init];
    _resultTextView.backgroundColor = [UIColor clearColor];
    _resultTextView.editable = NO;
    _resultTextView.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    _resultTextView.textColor = [UIColor labelColor];
    _resultTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_resultTextView];
    
    _clipboardBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_clipboardBtn setTitle:L(@"Copy Result", @"复制结果") forState:UIControlStateNormal];
    _clipboardBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    _clipboardBtn.backgroundColor = [UIColor systemGray5Color];
    [_clipboardBtn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    _clipboardBtn.layer.cornerRadius = 10;
    _clipboardBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [_clipboardBtn addTarget:self action:@selector(copyAction) forControlEvents:UIControlEventTouchUpInside];
    _clipboardBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_clipboardBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [_resultTextView.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [_resultTextView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [_resultTextView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [_resultTextView.heightAnchor constraintEqualToConstant:150],
        
        [_clipboardBtn.topAnchor constraintEqualToAnchor:_resultTextView.bottomAnchor constant:10],
        [_clipboardBtn.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [_clipboardBtn.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12]
    ]];
}

- (void)updateWithResultText:(NSString *)text isFinished:(BOOL)isFinished showRunOnTv:(BOOL)showRunOnTv {
    self.hidden = NO;
    self.resultTextView.text = text;
    if (isFinished) {
        [self.resultTextView scrollRangeToVisible:NSMakeRange(0, 0)];
    }
}

- (void)clearAndHide {
    self.resultTextView.text = @"";
    self.hidden = YES;
}

- (void)copyAction {
    if (self.onCopyResultRequested) {
        self.onCopyResultRequested(self.resultTextView.text ?: @"");
    }
}

- (void)applyThemeStyle {
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    self.backgroundColor = palette.cardBgColor;
    self.resultTextView.textColor = [UIColor whiteColor];
    [self.clipboardBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clipboardBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
}

@end
