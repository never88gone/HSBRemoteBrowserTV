//
//  HSBHomeBrowserControlCard.m
//  HSBWatchCompanion
//

#import "HSBHomeBrowserControlCard.h"

@interface HSBHomeBrowserControlCard () <UITextFieldDelegate>

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *urlTextField;
@property (nonatomic, strong) UIButton *goButton;
@property (nonatomic, strong) UIButton *openRemoteButton;
@property (nonatomic, strong) UIButton *editConfigButton;

@end

@implementation HSBHomeBrowserControlCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    self.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.layer.cornerRadius = 16;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.05;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8;
    
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    BOOL isZH = [language hasPrefix:@"zh"];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = isZH ? @"网页浏览器控制" : @"BROWSER CONTROLS";
    self.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.titleLabel];
    
    UIView *urlBarContainer = [[UIView alloc] init];
    urlBarContainer.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    urlBarContainer.layer.cornerRadius = 10;
    urlBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:urlBarContainer];
    
    UIImageView *urlIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    urlIcon.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    urlIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:urlIcon];
    
    self.urlTextField = [[UITextField alloc] init];
    self.urlTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:isZH ? @"输入网址跳转..." : @"Enter URL..." attributes:@{NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.3]}];
    self.urlTextField.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.urlTextField.textColor = [UIColor whiteColor];
    self.urlTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.urlTextField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.urlTextField.keyboardType = UIKeyboardTypeURL;
    self.urlTextField.returnKeyType = UIReturnKeyGo;
    self.urlTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.urlTextField.delegate = self;
    self.urlTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:self.urlTextField];
    
    self.goButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.goButton setImage:[UIImage systemImageNamed:@"arrow.right.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    [self.goButton addTarget:self action:@selector(handleGoTapped) forControlEvents:UIControlEventTouchUpInside];
    self.goButton.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:self.goButton];
    
    self.openRemoteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.openRemoteButton setTitle:isZH ? @"打开全屏触控板界面" : @"Open Fullscreen Trackpad" forState:UIControlStateNormal];
    self.openRemoteButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [self.openRemoteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.openRemoteButton.layer.cornerRadius = 12;
    [self.openRemoteButton addTarget:self action:@selector(handleOpenRemoteTapped) forControlEvents:UIControlEventTouchUpInside];
    self.openRemoteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.openRemoteButton];
    
    self.editConfigButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.editConfigButton setTitle:isZH ? @"编辑主页配置" : @"Edit Home Config" forState:UIControlStateNormal];
    self.editConfigButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.editConfigButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    [self.editConfigButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.editConfigButton.tintColor = [UIColor whiteColor];
    self.editConfigButton.layer.cornerRadius = 12;
    [self.editConfigButton addTarget:self action:@selector(handleEditConfigTapped) forControlEvents:UIControlEventTouchUpInside];
    self.editConfigButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.editConfigButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        
        [urlBarContainer.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:12],
        [urlBarContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [urlBarContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [urlBarContainer.heightAnchor constraintEqualToConstant:42],
        
        [urlIcon.leadingAnchor constraintEqualToAnchor:urlBarContainer.leadingAnchor constant:12],
        [urlIcon.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        [urlIcon.widthAnchor constraintEqualToConstant:18],
        [urlIcon.heightAnchor constraintEqualToConstant:18],
        
        [self.urlTextField.leadingAnchor constraintEqualToAnchor:urlIcon.trailingAnchor constant:8],
        [self.urlTextField.trailingAnchor constraintEqualToAnchor:self.goButton.leadingAnchor constant:-6],
        [self.urlTextField.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        
        [self.goButton.trailingAnchor constraintEqualToAnchor:urlBarContainer.trailingAnchor constant:-8],
        [self.goButton.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        [self.goButton.widthAnchor constraintEqualToConstant:28],
        [self.goButton.heightAnchor constraintEqualToConstant:28],
        
        [self.openRemoteButton.topAnchor constraintEqualToAnchor:urlBarContainer.bottomAnchor constant:12],
        [self.openRemoteButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.openRemoteButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.openRemoteButton.heightAnchor constraintEqualToConstant:54],
        
        [self.editConfigButton.topAnchor constraintEqualToAnchor:self.openRemoteButton.bottomAnchor constant:10],
        [self.editConfigButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.editConfigButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.editConfigButton.heightAnchor constraintEqualToConstant:44],
        [self.editConfigButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-20]
    ]];
}

- (void)handleGoTapped {
    [self.urlTextField resignFirstResponder];
    NSString *url = self.urlTextField.text;
    if (url.length > 0 && self.onOpenURLRequested) {
        self.onOpenURLRequested(url);
    }
}

- (void)handleOpenRemoteTapped {
    if (self.onOpenRemoteRequested) {
        self.onOpenRemoteRequested();
    }
}

- (void)handleEditConfigTapped {
    if (self.onEditHomeConfigRequested) {
        self.onEditHomeConfigRequested();
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self handleGoTapped];
    return YES;
}

- (void)applyThemePrimaryColor:(UIColor *)color {
    self.goButton.tintColor = color;
    self.openRemoteButton.backgroundColor = color;
}

@end
