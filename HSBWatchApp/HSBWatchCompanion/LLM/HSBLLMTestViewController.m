#import "HSBLLMTestViewController.h"
#import "HSBLocalLLMManager.h"
#import "HSBLLMModelCenterViewController.h"
#import "HSBTVOSConnectionManager.h"
#import "HSBLLMPromptManager.h"
#import "HSBLLMResultCardView.h"
#import "HSBLLMStatusCardView.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBLLMTestViewController () <UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentContainer;

// 顶部模型状态卡片
@property (nonatomic, strong) HSBLLMStatusCardView *statusCard;

// Segmented Control
@property (nonatomic, strong) UISegmentedControl *typeSegment;

// 语言选择区
@property (nonatomic, strong) UIView *languageConfigContainer;
@property (nonatomic, strong) UIButton *sourceLangBtn;
@property (nonatomic, strong) UIButton *targetLangBtn;
@property (nonatomic, strong) NSString *selectedSourceLang;
@property (nonatomic, strong) NSString *selectedTargetLang;

// 快捷 Prompt 标签区
@property (nonatomic, strong) UIScrollView *tagsScrollView;
@property (nonatomic, strong) UIView *tagsContainer;

// 输入区域
@property (nonatomic, strong) UIView *inputContainer;
@property (nonatomic, strong) UITextView *inputTextView;
@property (nonatomic, strong) UILabel *placeholderLabel;

// 推理测试按钮
@property (nonatomic, strong) UIButton *testBtn;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

// 结果卡片组件
@property (nonatomic, strong) HSBLLMResultCardView *resultCard;
@property (nonatomic, strong) UILabel *disclaimerLabel;

@end

@implementation HSBLLMTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"AI Assistant", @"AI 智能助手");
    
    NSString *sourceKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationSourceLanguage"] ?: @"Auto";
    NSString *targetKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
    
    self.selectedSourceLang = [[HSBLLMPromptManager sharedManager] languageNameForKey:sourceKey] ?: @"自动识别";
    self.selectedTargetLang = [[HSBLLMPromptManager sharedManager] languageNameForKey:targetKey] ?: @"中文";
    
    [self setupUI];
    [self updateQuickPromptTags];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleModelStatusChange:) name:@"HSBLocalLLMDownloadFinishedNotification" object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestRunAIGeneration"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.typeSegment.selectedSegmentIndex = 1;
            [self segmentChanged:self.typeSegment];
            self.inputTextView.text = @"让电视网页的背景变成粉红色";
            self.placeholderLabel.hidden = YES;
            [self runAIInference];
        });
    }
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    [self.statusCard applyThemeStyle];
    self.inputContainer.backgroundColor = palette.cardBgColor;
    [self.resultCard applyThemeStyle];
    
    self.inputTextView.textColor = [UIColor whiteColor];
    self.placeholderLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    
    self.typeSegment.selectedSegmentTintColor = palette.primaryColor;
    [self.typeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.7]} forState:UIControlStateNormal];
    [self.typeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    
    self.testBtn.backgroundColor = palette.primaryColor;
    [self.testBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [self updateQuickPromptTags];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleModelStatusChange:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.statusCard updateStatus];
    });
}

#pragma mark - UI Setup

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    self.contentContainer = [[UIView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentContainer];
    
    // Status Card
    self.statusCard = [[HSBLLMStatusCardView alloc] initWithFrame:CGRectZero];
    self.statusCard.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) weakSelf = self;
    self.statusCard.onActionBtnClicked = ^{
        [weakSelf goToActivateAction];
    };
    [self.contentContainer addSubview:self.statusCard];
    
    [self setupSegmentAndLanguageConfig];
    [self setupInputArea];
    [self setupResultAndDisclaimer];
    [self setupConstraints];
}

- (void)setupSegmentAndLanguageConfig {
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[L(@"Translation", @"同声传译"), L(@"Web Control", @"电视控制"), L(@"Smart Butler", @"智能管家")]];
    self.typeSegment.selectedSegmentIndex = 0;
    self.typeSegment.tintColor = [UIColor systemBlueColor];
    [self.typeSegment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.typeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.typeSegment];
    
    self.languageConfigContainer = [[UIView alloc] init];
    self.languageConfigContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.languageConfigContainer];
    
    self.sourceLangBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sourceLangBtn setTitle:[NSString stringWithFormat:@"源: %@", self.selectedSourceLang] forState:UIControlStateNormal];
    self.sourceLangBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.sourceLangBtn.backgroundColor = [UIColor systemGray6Color];
    self.sourceLangBtn.layer.cornerRadius = 8;
    self.sourceLangBtn.showsMenuAsPrimaryAction = YES;
    self.sourceLangBtn.menu = [self createLanguageMenuForButton:self.sourceLangBtn isSource:YES];
    self.sourceLangBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.languageConfigContainer addSubview:self.sourceLangBtn];
    
    UILabel *arrowLabel = [[UILabel alloc] init];
    arrowLabel.text = @"➡️";
    arrowLabel.font = [UIFont systemFontOfSize:14];
    arrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.languageConfigContainer addSubview:arrowLabel];
    
    self.targetLangBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.targetLangBtn setTitle:[NSString stringWithFormat:@"目标: %@", self.selectedTargetLang] forState:UIControlStateNormal];
    self.targetLangBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.targetLangBtn.backgroundColor = [UIColor systemGray6Color];
    self.targetLangBtn.layer.cornerRadius = 8;
    self.targetLangBtn.showsMenuAsPrimaryAction = YES;
    self.targetLangBtn.menu = [self createLanguageMenuForButton:self.targetLangBtn isSource:NO];
    self.targetLangBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.languageConfigContainer addSubview:self.targetLangBtn];
    
    self.tagsScrollView = [[UIScrollView alloc] init];
    self.tagsScrollView.showsHorizontalScrollIndicator = NO;
    self.tagsScrollView.alwaysBounceHorizontal = YES;
    self.tagsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.tagsScrollView];
    
    self.tagsContainer = [[UIView alloc] init];
    self.tagsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tagsScrollView addSubview:self.tagsContainer];
}

- (void)setupInputArea {
    self.inputContainer = [[UIView alloc] init];
    self.inputContainer.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.inputContainer.layer.cornerRadius = 16;
    self.inputContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    self.inputContainer.layer.shadowOpacity = 0.04;
    self.inputContainer.layer.shadowOffset = CGSizeMake(0, 3);
    self.inputContainer.layer.shadowRadius = 6;
    self.inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.inputContainer];
    
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
    [self.testBtn addTarget:self action:@selector(runAIInference) forControlEvents:UIControlEventTouchUpInside];
    self.testBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.testBtn];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [UIColor whiteColor];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.testBtn addSubview:self.spinner];
}

- (void)setupResultAndDisclaimer {
    self.resultCard = [[HSBLLMResultCardView alloc] initWithFrame:CGRectZero];
    self.resultCard.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) weakSelf = self;
    self.resultCard.onCopyResultRequested = ^(NSString * _Nonnull text) {
        [weakSelf handleCopyResult:text];
    };
    [self.contentContainer addSubview:self.resultCard];
    
    self.disclaimerLabel = [[UILabel alloc] init];
    self.disclaimerLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.disclaimerLabel.textColor = [UIColor secondaryLabelColor];
    self.disclaimerLabel.textAlignment = NSTextAlignmentCenter;
    self.disclaimerLabel.text = L(@"Note: AI-generated responses are for reference only.", @"注：AI 生成内容由端侧模型输出，仅供参考。");
    self.disclaimerLabel.numberOfLines = 0;
    self.disclaimerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.disclaimerLabel];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.contentContainer.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentContainer.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
        
        [self.statusCard.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:16],
        [self.statusCard.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.statusCard.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        
        [self.typeSegment.topAnchor constraintEqualToAnchor:self.statusCard.bottomAnchor constant:16],
        [self.typeSegment.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.typeSegment.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.typeSegment.heightAnchor constraintEqualToConstant:36],
        
        [self.languageConfigContainer.topAnchor constraintEqualToAnchor:self.typeSegment.bottomAnchor constant:12],
        [self.languageConfigContainer.centerXAnchor constraintEqualToAnchor:self.contentContainer.centerXAnchor],
        [self.languageConfigContainer.heightAnchor constraintEqualToConstant:32],
        
        [self.sourceLangBtn.leadingAnchor constraintEqualToAnchor:self.languageConfigContainer.leadingAnchor],
        [self.sourceLangBtn.centerYAnchor constraintEqualToAnchor:self.languageConfigContainer.centerYAnchor],
        [self.sourceLangBtn.widthAnchor constraintEqualToConstant:100],
        [self.sourceLangBtn.heightAnchor constraintEqualToConstant:32],
        
        [[self.languageConfigContainer.subviews objectAtIndex:1].leadingAnchor constraintEqualToAnchor:self.sourceLangBtn.trailingAnchor constant:12],
        [[self.languageConfigContainer.subviews objectAtIndex:1].centerYAnchor constraintEqualToAnchor:self.languageConfigContainer.centerYAnchor],
        
        [self.targetLangBtn.leadingAnchor constraintEqualToAnchor:[self.languageConfigContainer.subviews objectAtIndex:1].trailingAnchor constant:12],
        [self.targetLangBtn.centerYAnchor constraintEqualToAnchor:self.languageConfigContainer.centerYAnchor],
        [self.targetLangBtn.trailingAnchor constraintEqualToAnchor:self.languageConfigContainer.trailingAnchor],
        [self.targetLangBtn.widthAnchor constraintEqualToConstant:100],
        [self.targetLangBtn.heightAnchor constraintEqualToConstant:32],
        
        [self.tagsScrollView.topAnchor constraintEqualToAnchor:self.languageConfigContainer.bottomAnchor constant:12],
        [self.tagsScrollView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.tagsScrollView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [self.tagsScrollView.heightAnchor constraintEqualToConstant:40],
        
        [self.tagsContainer.topAnchor constraintEqualToAnchor:self.tagsScrollView.topAnchor],
        [self.tagsContainer.leadingAnchor constraintEqualToAnchor:self.tagsScrollView.leadingAnchor],
        [self.tagsContainer.trailingAnchor constraintEqualToAnchor:self.tagsScrollView.trailingAnchor],
        [self.tagsContainer.bottomAnchor constraintEqualToAnchor:self.tagsScrollView.bottomAnchor],
        [self.tagsContainer.heightAnchor constraintEqualToAnchor:self.tagsScrollView.heightAnchor],
        
        [self.inputContainer.topAnchor constraintEqualToAnchor:self.tagsScrollView.bottomAnchor constant:12],
        [self.inputContainer.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.inputContainer.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.inputContainer.heightAnchor constraintEqualToConstant:120],
        
        [self.inputTextView.topAnchor constraintEqualToAnchor:self.inputContainer.topAnchor constant:10],
        [self.inputTextView.leadingAnchor constraintEqualToAnchor:self.inputContainer.leadingAnchor constant:12],
        [self.inputTextView.trailingAnchor constraintEqualToAnchor:self.inputContainer.trailingAnchor constant:-12],
        [self.inputTextView.bottomAnchor constraintEqualToAnchor:self.inputContainer.bottomAnchor constant:-10],
        
        [self.placeholderLabel.topAnchor constraintEqualToAnchor:self.inputContainer.topAnchor constant:18],
        [self.placeholderLabel.leadingAnchor constraintEqualToAnchor:self.inputContainer.leadingAnchor constant:17],
        [self.placeholderLabel.trailingAnchor constraintEqualToAnchor:self.inputContainer.trailingAnchor constant:-17],
        
        [self.testBtn.topAnchor constraintEqualToAnchor:self.inputContainer.bottomAnchor constant:16],
        [self.testBtn.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.testBtn.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.testBtn.heightAnchor constraintEqualToConstant:50],
        
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.testBtn.centerYAnchor],
        [self.spinner.trailingAnchor constraintEqualToAnchor:self.testBtn.trailingAnchor constant:-20],
        
        [self.resultCard.topAnchor constraintEqualToAnchor:self.testBtn.bottomAnchor constant:16],
        [self.resultCard.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.resultCard.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        
        [self.disclaimerLabel.topAnchor constraintEqualToAnchor:self.resultCard.bottomAnchor constant:16],
        [self.disclaimerLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.disclaimerLabel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.disclaimerLabel.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-24]
    ]];
}

#pragma mark - UI Actions

- (void)goToActivateAction {
    HSBLLMModelCenterViewController *vc = [[HSBLLMModelCenterViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    BOOL isTranslation = (sender.selectedSegmentIndex == 0);
    self.languageConfigContainer.hidden = !isTranslation;
    
    [self updateQuickPromptTags];
    self.inputTextView.text = @"";
    self.placeholderLabel.hidden = NO;
    [self.resultCard clearAndHide];
}

- (UIMenu *)createLanguageMenuForButton:(UIButton *)btn isSource:(BOOL)isSource {
    NSArray *langs = [[HSBLLMPromptManager sharedManager] supportedLanguagesForSource:isSource];
    NSMutableArray *actions = [NSMutableArray array];
    for (NSString *lang in langs) {
        __weak typeof(self) weakSelf = self;
        UIAction *action = [UIAction actionWithTitle:lang image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            NSString *key = [[HSBLLMPromptManager sharedManager] languageKeyForName:lang];
            if (isSource) {
                weakSelf.selectedSourceLang = lang;
                [btn setTitle:[NSString stringWithFormat:@"源: %@", lang] forState:UIControlStateNormal];
                [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"HSBTranslationSourceLanguage"];
            } else {
                weakSelf.selectedTargetLang = lang;
                [btn setTitle:[NSString stringWithFormat:@"目标: %@", lang] forState:UIControlStateNormal];
                [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"HSBTranslationTargetLanguage"];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
        [actions addObject:action];
    }
    return [UIMenu menuWithTitle:@"选择语言" children:actions];
}

- (void)tagPressed:(UIButton *)sender {
    HSBLLMTestScenarioType scenario = (HSBLLMTestScenarioType)self.typeSegment.selectedSegmentIndex;
    NSString *prompt = [[HSBLLMPromptManager sharedManager] promptTextForScenario:scenario atIndex:sender.tag];
    if (prompt.length > 0) {
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [hap impactOccurred];
        self.inputTextView.text = prompt;
        self.placeholderLabel.hidden = YES;
    }
}

- (void)runAIInference {
    NSString *prompt = [self.inputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (prompt.length == 0) return;
    
    [self.inputTextView resignFirstResponder];
    self.testBtn.enabled = NO;
    self.testBtn.alpha = 0.7;
    [self.spinner startAnimating];
    [self.testBtn setTitle:L(@"AI Generating...", @"端侧智能生成中...") forState:UIControlStateNormal];
    
    HSBLLMTestScenarioType scenario = (HSBLLMTestScenarioType)self.typeSegment.selectedSegmentIndex;
    NSInteger type = (scenario == HSBLLMTestScenarioWebControl) ? 2 : (scenario == HSBLLMTestScenarioSmartButler ? 3 : 1);
    NSString *systemPrompt = [[HSBLLMPromptManager sharedManager] systemPromptForScenario:scenario];
    NSString *enhancedUserPrompt = [[HSBLLMPromptManager sharedManager] enhancedUserPromptForScenario:scenario
                                                                                          userPrompt:prompt
                                                                                      sourceLanguage:self.selectedSourceLang
                                                                                      targetLanguage:self.selectedTargetLang];
    
    __weak typeof(self) weakSelf = self;
    [[HSBLocalLLMManager shared] processMessage:enhancedUserPrompt systemPrompt:systemPrompt type:type completion:^(NSString * _Nonnull response, BOOL isFinished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.resultCard updateWithResultText:response isFinished:isFinished showRunOnTv:(scenario == HSBLLMTestScenarioWebControl)];
            
            if (isFinished) {
                [weakSelf.spinner stopAnimating];
                weakSelf.testBtn.enabled = YES;
                weakSelf.testBtn.alpha = 1.0;
                [weakSelf.testBtn setTitle:L(@"Start AI Generation", @"开始 AI 生成") forState:UIControlStateNormal];
                
                UINotificationFeedbackGenerator *hap = [[UINotificationFeedbackGenerator alloc] init];
                [hap notificationOccurred:UINotificationFeedbackTypeSuccess];
            }
        });
    }];
}

- (void)handleCopyResult:(NSString *)text {
    if (text.length > 0) {
        [UIPasteboard generalPasteboard].string = text;
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [hap impactOccurred];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Success", @"成功")
                                                                       message:L(@"Copied to clipboard!", @"已成功复制到剪切板！")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alert animated:YES completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = (textView.text.length > 0);
}

- (void)updateQuickPromptTags {
    if (!self.tagsContainer) return;
    
    for (UIView *v in self.tagsContainer.subviews) {
        [v removeFromSuperview];
    }
    
    HSBLLMTestScenarioType scenario = (HSBLLMTestScenarioType)self.typeSegment.selectedSegmentIndex;
    NSArray *prompts = [[HSBLLMPromptManager sharedManager] quickPromptTagsForScenario:scenario];
    self.placeholderLabel.text = [[HSBLLMPromptManager sharedManager] placeholderTextForScenario:scenario];
    self.placeholderLabel.hidden = (self.inputTextView.text.length > 0);
    
    UIView *lastView = nil;
    for (int i = 0; i < prompts.count; i++) {
        NSString *title = prompts[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:title forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        btn.backgroundColor = [[HSBThemeManager shared].currentPalette.primaryColor colorWithAlphaComponent:0.12];
        btn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
        btn.layer.cornerRadius = 14;
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        btn.tag = i;
        [btn addTarget:self action:@selector(tagPressed:) forControlEvents:UIControlEventTouchUpInside];
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

@end
