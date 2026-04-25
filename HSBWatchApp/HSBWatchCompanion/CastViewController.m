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
@end

@implementation CastViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // URL Bar
    UIView *urlBarContainer = [[UIView alloc] init];
    urlBarContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
    urlBarContainer.layer.cornerRadius = 10;
    urlBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:urlBarContainer];
    
    UIImageView *urlIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    urlIcon.tintColor = [UIColor secondaryLabelColor];
    urlIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:urlIcon];
    
    self.urlTextField = [[UITextField alloc] init];
    self.urlTextField.placeholder = L(@"Enter URL to cast...", @"输入视频或网页链接并投屏...");
    self.urlTextField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.urlTextField.textColor = [UIColor labelColor];
    self.urlTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.urlTextField.keyboardType = UIKeyboardTypeURL;
    self.urlTextField.returnKeyType = UIReturnKeyGo;
    self.urlTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.urlTextField.delegate = self;
    self.urlTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:self.urlTextField];
    
    UIButton *goBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [goBtn setImage:[UIImage systemImageNamed:@"paperplane.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    goBtn.tintColor = [UIColor systemBlueColor];
    [goBtn addTarget:self action:@selector(sendUrl) forControlEvents:UIControlEventTouchUpInside];
    goBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:goBtn];
    
    UILabel *hint = [[UILabel alloc] init];
    hint.text = L(@"Send any web link directly to the TV's browser.", @"支持发送绝大部分流媒体网页链接至大屏浏览器直接解析播放。");
    hint.font = [UIFont systemFontOfSize:13];
    hint.textColor = [UIColor secondaryLabelColor];
    hint.numberOfLines = 0;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:hint];
    
    [NSLayoutConstraint activateConstraints:@[
        [urlBarContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:40],
        [urlBarContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [urlBarContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [urlBarContainer.heightAnchor constraintEqualToConstant:55],
        
        [urlIcon.leadingAnchor constraintEqualToAnchor:urlBarContainer.leadingAnchor constant:16],
        [urlIcon.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        [urlIcon.widthAnchor constraintEqualToConstant:20],
        [urlIcon.heightAnchor constraintEqualToConstant:20],
        
        [self.urlTextField.leadingAnchor constraintEqualToAnchor:urlIcon.trailingAnchor constant:12],
        [self.urlTextField.topAnchor constraintEqualToAnchor:urlBarContainer.topAnchor],
        [self.urlTextField.bottomAnchor constraintEqualToAnchor:urlBarContainer.bottomAnchor],
        
        [goBtn.leadingAnchor constraintEqualToAnchor:self.urlTextField.trailingAnchor constant:4],
        [goBtn.trailingAnchor constraintEqualToAnchor:urlBarContainer.trailingAnchor constant:-12],
        [goBtn.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        [goBtn.widthAnchor constraintEqualToConstant:35],
        [goBtn.heightAnchor constraintEqualToConstant:35],
        
        [hint.topAnchor constraintEqualToAnchor:urlBarContainer.bottomAnchor constant:16],
        [hint.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:25],
        [hint.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-25]
    ]];
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
