//
//  HSBLLMInputPanel.m
//  HSBWatchCompanion
//

#import "HSBLLMInputPanel.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBLLMInputPanel () <UITextViewDelegate>

@property (nonatomic, strong) UIView *inputContainer;
@property (nonatomic, strong, readwrite) UITextView *inputTextView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong, readwrite) UIButton *testBtn;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIScrollView *tagsScrollView;
@property (nonatomic, strong) UIView *tagsContainer;

@end

@implementation HSBLLMInputPanel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.tagsScrollView = [[UIScrollView alloc] init];
    self.tagsScrollView.showsHorizontalScrollIndicator = NO;
    self.tagsScrollView.alwaysBounceHorizontal = YES;
    self.tagsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.tagsScrollView];
    
    self.tagsContainer = [[UIView alloc] init];
    self.tagsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tagsScrollView addSubview:self.tagsContainer];
    
    self.inputContainer = [[UIView alloc] init];
    self.inputContainer.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.inputContainer.layer.cornerRadius = 16;
    self.inputContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    self.inputContainer.layer.shadowOpacity = 0.04;
    self.inputContainer.layer.shadowOffset = CGSizeMake(0, 3);
    self.inputContainer.layer.shadowRadius = 6;
    self.inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.inputContainer];
    
    self.inputTextView = [[UITextView alloc] init];
    self.inputTextView.backgroundColor = [UIColor clearColor];
    self.inputTextView.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.inputTextView.textColor = [UIColor labelColor];
    self.inputTextView.delegate = self;
    self.inputTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.inputContainer addSubview:self.inputTextView];
    
    self.placeholderLabel = [[UILabel alloc] init];
    self.placeholderLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.placeholderLabel.textColor = [UIColor placeholderTextColor];
    self.placeholderLabel.numberOfLines = 0;
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.inputContainer addSubview:self.placeholderLabel];
    
    self.testBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.testBtn.backgroundColor = [UIColor systemPurpleColor];
    [self.testBtn setTitle:L(@"Start AI Generation", @"开始 AI 生成") forState:UIControlStateNormal];
    self.testBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.testBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.testBtn.layer.cornerRadius = 14;
    [self.testBtn addTarget:self action:@selector(handleStartGenerate) forControlEvents:UIControlEventTouchUpInside];
    self.testBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.testBtn];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [UIColor whiteColor];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.testBtn addSubview:self.spinner];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tagsScrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.tagsScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.tagsScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.tagsScrollView.heightAnchor constraintEqualToConstant:36],
        
        [self.tagsContainer.topAnchor constraintEqualToAnchor:self.tagsScrollView.topAnchor],
        [self.tagsContainer.bottomAnchor constraintEqualToAnchor:self.tagsScrollView.bottomAnchor],
        [self.tagsContainer.leadingAnchor constraintEqualToAnchor:self.tagsScrollView.leadingAnchor],
        [self.tagsContainer.trailingAnchor constraintEqualToAnchor:self.tagsScrollView.trailingAnchor],
        [self.tagsContainer.heightAnchor constraintEqualToAnchor:self.tagsScrollView.heightAnchor],
        
        [self.inputContainer.topAnchor constraintEqualToAnchor:self.tagsScrollView.bottomAnchor constant:12],
        [self.inputContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.inputContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.inputContainer.heightAnchor constraintEqualToConstant:100],
        
        [self.inputTextView.topAnchor constraintEqualToAnchor:self.inputContainer.topAnchor constant:8],
        [self.inputTextView.leadingAnchor constraintEqualToAnchor:self.inputContainer.leadingAnchor constant:12],
        [self.inputTextView.trailingAnchor constraintEqualToAnchor:self.inputContainer.trailingAnchor constant:-12],
        [self.inputTextView.bottomAnchor constraintEqualToAnchor:self.inputContainer.bottomAnchor constant:-8],
        
        [self.placeholderLabel.topAnchor constraintEqualToAnchor:self.inputContainer.topAnchor constant:16],
        [self.placeholderLabel.leadingAnchor constraintEqualToAnchor:self.inputContainer.leadingAnchor constant:16],
        [self.placeholderLabel.trailingAnchor constraintEqualToAnchor:self.inputContainer.trailingAnchor constant:-16],
        
        [self.testBtn.topAnchor constraintEqualToAnchor:self.inputContainer.bottomAnchor constant:14],
        [self.testBtn.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.testBtn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.testBtn.heightAnchor constraintEqualToConstant:50],
        [self.testBtn.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.testBtn.centerYAnchor],
        [self.spinner.trailingAnchor constraintEqualToAnchor:self.testBtn.trailingAnchor constant:-20]
    ]];
}

- (void)handleStartGenerate {
    NSString *text = [self.inputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length > 0 && self.onStartGenerateRequested) {
        self.onStartGenerateRequested(text);
    }
}

- (void)updatePlaceholder:(NSString *)placeholder {
    self.placeholderLabel.text = placeholder;
    self.placeholderLabel.hidden = (self.inputTextView.text.length > 0);
}

- (void)setInputText:(NSString *)text {
    self.inputTextView.text = text;
    self.placeholderLabel.hidden = (text.length > 0);
}

- (void)setQuickPromptTags:(NSArray<NSString *> *)tags primaryColor:(UIColor *)primaryColor {
    for (UIView *v in self.tagsContainer.subviews) {
        [v removeFromSuperview];
    }
    
    UIView *lastView = nil;
    for (NSInteger i = 0; i < tags.count; i++) {
        NSString *title = tags[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:title forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        btn.backgroundColor = [primaryColor colorWithAlphaComponent:0.12];
        btn.tintColor = primaryColor;
        btn.layer.cornerRadius = 14;
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        btn.tag = i;
        [btn addTarget:self action:@selector(handleTagPressed:) forControlEvents:UIControlEventTouchUpInside];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [self.tagsContainer addSubview:btn];
        
        [NSLayoutConstraint activateConstraints:@[
            [btn.centerYAnchor constraintEqualToAnchor:self.tagsContainer.centerYAnchor],
            [btn.heightAnchor constraintEqualToConstant:28]
        ]];
        
        if (lastView == nil) {
            [btn.leadingAnchor constraintEqualToAnchor:self.tagsContainer.leadingAnchor constant:16].active = YES;
        } else {
            [btn.leadingAnchor constraintEqualToAnchor:lastView.trailingAnchor constant:8].active = YES;
        }
        lastView = btn;
    }
    
    if (lastView) {
        [lastView.trailingAnchor constraintEqualToAnchor:self.tagsContainer.trailingAnchor constant:-16].active = YES;
    }
}

- (void)handleTagPressed:(UIButton *)sender {
    if (self.onQuickTagSelected) {
        self.onQuickTagSelected(sender.tag);
    }
}

- (void)setGeneratingState:(BOOL)isGenerating {
    if (isGenerating) {
        [self.inputTextView resignFirstResponder];
        self.testBtn.enabled = NO;
        self.testBtn.alpha = 0.7;
        [self.spinner startAnimating];
        [self.testBtn setTitle:L(@"AI Generating...", @"端侧智能生成中...") forState:UIControlStateNormal];
    } else {
        [self.spinner stopAnimating];
        self.testBtn.enabled = YES;
        self.testBtn.alpha = 1.0;
        [self.testBtn setTitle:L(@"Start AI Generation", @"开始 AI 生成") forState:UIControlStateNormal];
    }
}

- (void)applyThemePrimaryColor:(UIColor *)primaryColor {
    self.testBtn.backgroundColor = primaryColor;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = (textView.text.length > 0);
}

@end
