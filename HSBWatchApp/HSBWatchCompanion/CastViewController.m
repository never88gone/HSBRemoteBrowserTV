//
//  CastViewController.m
//  HSBWatchCompanion
//

#import "CastViewController.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface CastViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *urlTextField;
@property (nonatomic, strong) UIButton *goBtn;
@property (nonatomic, strong) UIView *urlBarContainer;
@property (nonatomic, strong) UILabel *hint;
@end

@implementation CastViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // URL Bar Container - 高贵 8% 磨砂白叠底
    self.urlBarContainer = [[UIView alloc] init];
    self.urlBarContainer.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    self.urlBarContainer.layer.cornerRadius = 12;
    self.urlBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.urlBarContainer];
    
    UIImageView *urlIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    urlIcon.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    urlIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.urlBarContainer addSubview:urlIcon];
    
    self.urlTextField = [[UITextField alloc] init];
    self.urlTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:L(@"Enter URL to cast...", @"输入视频或网页链接并投屏...") attributes:@{NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.3]}];
    self.urlTextField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.urlTextField.textColor = [UIColor whiteColor];
    self.urlTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.urlTextField.keyboardType = UIKeyboardTypeURL;
    self.urlTextField.returnKeyType = UIReturnKeyGo;
    self.urlTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.urlTextField.delegate = self;
    self.urlTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.urlBarContainer addSubview:self.urlTextField];
    
    self.goBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.goBtn setImage:[UIImage systemImageNamed:@"paperplane.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    self.goBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self.goBtn addTarget:self action:@selector(sendUrl) forControlEvents:UIControlEventTouchUpInside];
    self.goBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.urlBarContainer addSubview:self.goBtn];
    
    self.hint = [[UILabel alloc] init];
    self.hint.text = L(@"Send any web link directly to the TV's browser.", @"支持发送绝大部分流媒体网页链接至大屏浏览器直接解析播放。");
    self.hint.font = [UIFont systemFontOfSize:13];
    self.hint.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    self.hint.numberOfLines = 0;
    self.hint.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hint];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.urlBarContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:40],
        [self.urlBarContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.urlBarContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.urlBarContainer.heightAnchor constraintEqualToConstant:55],
        
        [urlIcon.leadingAnchor constraintEqualToAnchor:self.urlBarContainer.leadingAnchor constant:16],
        [urlIcon.centerYAnchor constraintEqualToAnchor:self.urlBarContainer.centerYAnchor],
        [urlIcon.widthAnchor constraintEqualToConstant:20],
        [urlIcon.heightAnchor constraintEqualToConstant:20],
        
        [self.urlTextField.leadingAnchor constraintEqualToAnchor:urlIcon.trailingAnchor constant:12],
        [self.urlTextField.topAnchor constraintEqualToAnchor:self.urlBarContainer.topAnchor],
        [self.urlTextField.bottomAnchor constraintEqualToAnchor:self.urlBarContainer.bottomAnchor],
        
        [self.goBtn.leadingAnchor constraintEqualToAnchor:self.urlTextField.trailingAnchor constant:4],
        [self.goBtn.trailingAnchor constraintEqualToAnchor:self.urlBarContainer.trailingAnchor constant:-12],
        [self.goBtn.centerYAnchor constraintEqualToAnchor:self.urlBarContainer.centerYAnchor],
        [self.goBtn.widthAnchor constraintEqualToConstant:35],
        [self.goBtn.heightAnchor constraintEqualToConstant:35],
        
        [self.hint.topAnchor constraintEqualToAnchor:self.urlBarContainer.bottomAnchor constant:16],
        [self.hint.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:25],
        [self.hint.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-25]
    ]];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    self.goBtn.tintColor = palette.primaryColor;
}

- (void)sendUrl {
    NSString *url = self.urlTextField.text;
    if (url.length == 0) return;
    
    if (![url hasPrefix:@"http://"] && ![url hasPrefix:@"https://"]) {
        url = [NSString stringWithFormat:@"https://%@", url];
    }
    [self.urlTextField resignFirstResponder];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{@"action": @"open_url", @"url": url});
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendUrl];
    return YES;
}

@end
