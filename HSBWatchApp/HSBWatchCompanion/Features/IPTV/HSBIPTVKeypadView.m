#import "HSBIPTVKeypadView.h"
#import "HSBThemeManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBIPTVKeypadView ()

@property (nonatomic, strong) UILabel *keypadDisplayLabel;
@property (nonatomic, strong) UIButton *keypadClearBtn;
@property (nonatomic, strong) NSMutableString *currentDigits;
@property (nonatomic, strong) NSTimer *autoCommitTimer;

@end

@implementation HSBIPTVKeypadView

- (void)dealloc {
    [_autoCommitTimer invalidate];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _currentDigits = [NSMutableString string];
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    UIView *displayBox = [[UIView alloc] init];
    displayBox.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    displayBox.layer.cornerRadius = 12;
    displayBox.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:displayBox];
    
    self.keypadDisplayLabel = [[UILabel alloc] init];
    self.keypadDisplayLabel.text = L(@"Channel: ---", @"频道: ---");
    self.keypadDisplayLabel.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightBold];
    self.keypadDisplayLabel.textColor = [HSBThemeManager shared].currentPalette.primaryColor;
    self.keypadDisplayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [displayBox addSubview:self.keypadDisplayLabel];
    
    self.keypadClearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.keypadClearBtn setImage:[UIImage systemImageNamed:@"delete.left.fill"] forState:UIControlStateNormal];
    self.keypadClearBtn.tintColor = [UIColor secondaryLabelColor];
    [self.keypadClearBtn addTarget:self action:@selector(keypadBackspace) forControlEvents:UIControlEventTouchUpInside];
    self.keypadClearBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [displayBox addSubview:self.keypadClearBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [displayBox.topAnchor constraintEqualToAnchor:self.topAnchor],
        [displayBox.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
        [displayBox.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
        [displayBox.heightAnchor constraintEqualToConstant:36],
        
        [self.keypadDisplayLabel.centerYAnchor constraintEqualToAnchor:displayBox.centerYAnchor],
        [self.keypadDisplayLabel.leadingAnchor constraintEqualToAnchor:displayBox.leadingAnchor constant:14],
        
        [self.keypadClearBtn.centerYAnchor constraintEqualToAnchor:displayBox.centerYAnchor],
        [self.keypadClearBtn.trailingAnchor constraintEqualToAnchor:displayBox.trailingAnchor constant:-10],
        [self.keypadClearBtn.widthAnchor constraintEqualToConstant:30],
        [self.keypadClearBtn.heightAnchor constraintEqualToConstant:30]
    ]];
    
    UIStackView *vertStack = [[UIStackView alloc] init];
    vertStack.axis = UILayoutConstraintAxisVertical;
    vertStack.distribution = UIStackViewDistributionFillEqually;
    vertStack.spacing = 8;
    vertStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:vertStack];
    
    NSArray *rows = @[
        @[@"1", @"2", @"3"],
        @[@"4", @"5", @"6"],
        @[@"7", @"8", @"9"],
        @[@"CLR", @"0", @"OK"]
    ];
    
    for (NSArray *row in rows) {
        UIStackView *horzStack = [[UIStackView alloc] init];
        horzStack.axis = UILayoutConstraintAxisHorizontal;
        horzStack.distribution = UIStackViewDistributionFillEqually;
        horzStack.spacing = 12;
        
        for (NSString *val in row) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.07];
            btn.layer.cornerRadius = 14;
            [btn setTitle:val forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
            
            if ([val isEqualToString:@"OK"]) {
                btn.backgroundColor = [[HSBThemeManager shared].currentPalette.primaryColor colorWithAlphaComponent:0.25];
                [btn setTitleColor:[HSBThemeManager shared].currentPalette.primaryColor forState:UIControlStateNormal];
                [btn addTarget:self action:@selector(keypadOK) forControlEvents:UIControlEventTouchUpInside];
            } else if ([val isEqualToString:@"CLR"]) {
                [btn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
                [btn addTarget:self action:@selector(keypadClearAll) forControlEvents:UIControlEventTouchUpInside];
            } else {
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                [btn addTarget:self action:@selector(keypadDigitPressed:) forControlEvents:UIControlEventTouchUpInside];
            }
            [horzStack addArrangedSubview:btn];
        }
        [vertStack addArrangedSubview:horzStack];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [vertStack.topAnchor constraintEqualToAnchor:displayBox.bottomAnchor constant:8],
        [vertStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
        [vertStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
        [vertStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4]
    ]];
}

- (void)keypadDigitPressed:(UIButton *)sender {
    NSString *digit = [sender titleForState:UIControlStateNormal];
    if (!digit) return;
    
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    [self.currentDigits appendString:digit];
    self.keypadDisplayLabel.text = [NSString stringWithFormat:L(@"Channel: %@", @"频道: %@"), self.currentDigits];
    
    [self.autoCommitTimer invalidate];
    self.autoCommitTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(keypadOK) userInfo:nil repeats:NO];
}

- (void)keypadBackspace {
    if (self.currentDigits.length > 0) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [fb impactOccurred];
        [self.currentDigits deleteCharactersInRange:NSMakeRange(self.currentDigits.length - 1, 1)];
        if (self.currentDigits.length == 0) {
            self.keypadDisplayLabel.text = L(@"Channel: ---", @"频道: ---");
        } else {
            self.keypadDisplayLabel.text = [NSString stringWithFormat:L(@"Channel: %@", @"频道: %@"), self.currentDigits];
        }
    }
}

- (void)keypadClearAll {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    [self clearAll];
}

- (void)clearAll {
    [self.currentDigits setString:@""];
    self.keypadDisplayLabel.text = L(@"Channel: ---", @"频道: ---");
    [self.autoCommitTimer invalidate];
}

- (void)keypadOK {
    [self.autoCommitTimer invalidate];
    if (self.currentDigits.length == 0) return;
    
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    
    NSString *chan = [self.currentDigits copy];
    [self clearAll];
    
    if (self.onCommitChannelBlock) {
        self.onCommitChannelBlock(chan);
    }
}

- (void)applyThemeStyle {
    self.keypadDisplayLabel.textColor = [HSBThemeManager shared].currentPalette.primaryColor;
}

@end
