//
//  HSBLLMTestViewController.m
//  HSBWatchCompanion
//

#import "HSBLLMTestViewController.h"
#import "HSBLocalLLMManager.h"
#import "HSBThemeManager.h"
#import "HSBLLMModelCenterViewController.h"
#import "HSBLLMPromptManager.h"
#import "HSBLLMStatusCardView.h"
#import "HSBLLMResultCardView.h"
#import "HSBLLMInputPanel.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBLLMTestViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentContainer;

@property (nonatomic, strong) HSBLLMStatusCardView *statusCard;
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, strong) UIView *languageConfigContainer;
@property (nonatomic, strong) UIButton *sourceLangBtn;
@property (nonatomic, strong) UIButton *targetLangBtn;

@property (nonatomic, strong) HSBLLMInputPanel *inputPanel;
@property (nonatomic, strong) HSBLLMResultCardView *resultCard;
@property (nonatomic, strong) UILabel *disclaimerLabel;

@property (nonatomic, copy) NSString *selectedSourceLang;
@property (nonatomic, copy) NSString *selectedTargetLang;

@end

@implementation HSBLLMTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"AI Intelligence", @"端侧大模型实验室");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    self.selectedSourceLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationSourceLanguage"] ?: @"Auto";
    self.selectedTargetLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
    
    [self setupUI];
    [self updateQuickPromptTags];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleModelStatusChange:)
                                                 name:@"HSBLocalLLMDownloadFinishedNotification"
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.statusCard updateStatus];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    UIColor *primary = [HSBThemeManager shared].currentPalette.primaryColor;
    self.typeSegment.selectedSegmentTintColor = primary;
    [self.inputPanel applyThemePrimaryColor:primary];
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
    
    self.statusCard = [[HSBLLMStatusCardView alloc] initWithFrame:CGRectZero];
    self.statusCard.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) weakSelf = self;
    self.statusCard.onActionBtnClicked = ^{
        [weakSelf goToActivateAction];
    };
    [self.contentContainer addSubview:self.statusCard];
    
    [self setupSegmentAndLanguageConfig];
    
    self.inputPanel = [[HSBLLMInputPanel alloc] init];
    self.inputPanel.onStartGenerateRequested = ^(NSString * _Nonnull text) {
        [weakSelf runAIInferenceWithPrompt:text];
    };
    self.inputPanel.onQuickTagSelected = ^(NSInteger index) {
        [weakSelf tagPressedAtIndex:index];
    };
    [self.contentContainer addSubview:self.inputPanel];
    
    self.resultCard = [[HSBLLMResultCardView alloc] initWithFrame:CGRectZero];
    self.resultCard.translatesAutoresizingMaskIntoConstraints = NO;
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
    
    [NSLayoutConstraint activateConstraints:@[
        [self.sourceLangBtn.leadingAnchor constraintEqualToAnchor:self.languageConfigContainer.leadingAnchor],
        [self.sourceLangBtn.topAnchor constraintEqualToAnchor:self.languageConfigContainer.topAnchor],
        [self.sourceLangBtn.bottomAnchor constraintEqualToAnchor:self.languageConfigContainer.bottomAnchor],
        [self.sourceLangBtn.widthAnchor constraintEqualToConstant:120],
        
        [arrowLabel.centerXAnchor constraintEqualToAnchor:self.languageConfigContainer.centerXAnchor],
        [arrowLabel.centerYAnchor constraintEqualToAnchor:self.languageConfigContainer.centerYAnchor],
        
        [self.targetLangBtn.trailingAnchor constraintEqualToAnchor:self.languageConfigContainer.trailingAnchor],
        [self.targetLangBtn.topAnchor constraintEqualToAnchor:self.languageConfigContainer.topAnchor],
        [self.targetLangBtn.bottomAnchor constraintEqualToAnchor:self.languageConfigContainer.bottomAnchor],
        [self.targetLangBtn.widthAnchor constraintEqualToConstant:120]
    ]];
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
        
        [self.statusCard.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:12],
        [self.statusCard.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.statusCard.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        
        [self.typeSegment.topAnchor constraintEqualToAnchor:self.statusCard.bottomAnchor constant:14],
        [self.typeSegment.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.typeSegment.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.typeSegment.heightAnchor constraintEqualToConstant:34],
        
        [self.languageConfigContainer.topAnchor constraintEqualToAnchor:self.typeSegment.bottomAnchor constant:12],
        [self.languageConfigContainer.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.languageConfigContainer.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.languageConfigContainer.heightAnchor constraintEqualToConstant:36],
        
        [self.inputPanel.topAnchor constraintEqualToAnchor:self.languageConfigContainer.bottomAnchor constant:12],
        [self.inputPanel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.inputPanel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        
        [self.resultCard.topAnchor constraintEqualToAnchor:self.inputPanel.bottomAnchor constant:14],
        [self.resultCard.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.resultCard.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        
        [self.disclaimerLabel.topAnchor constraintEqualToAnchor:self.resultCard.bottomAnchor constant:20],
        [self.disclaimerLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.disclaimerLabel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.disclaimerLabel.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-40]
    ]];
}

- (void)goToActivateAction {
    HSBLLMModelCenterViewController *vc = [[HSBLLMModelCenterViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    BOOL isTranslation = (sender.selectedSegmentIndex == 0);
    self.languageConfigContainer.hidden = !isTranslation;
    [self updateQuickPromptTags];
    [self.inputPanel setInputText:@""];
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

- (void)tagPressedAtIndex:(NSInteger)index {
    HSBLLMTestScenarioType scenario = (HSBLLMTestScenarioType)self.typeSegment.selectedSegmentIndex;
    NSString *prompt = [[HSBLLMPromptManager sharedManager] promptTextForScenario:scenario atIndex:index];
    if (prompt.length > 0) {
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [hap impactOccurred];
        [self.inputPanel setInputText:prompt];
    }
}

- (void)runAIInferenceWithPrompt:(NSString *)prompt {
    [self.inputPanel setGeneratingState:YES];
    
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
                [weakSelf.inputPanel setGeneratingState:NO];
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

- (void)updateQuickPromptTags {
    HSBLLMTestScenarioType scenario = (HSBLLMTestScenarioType)self.typeSegment.selectedSegmentIndex;
    NSArray *prompts = [[HSBLLMPromptManager sharedManager] quickPromptTagsForScenario:scenario];
    [self.inputPanel updatePlaceholder:[[HSBLLMPromptManager sharedManager] placeholderTextForScenario:scenario]];
    [self.inputPanel setQuickPromptTags:prompts primaryColor:[HSBThemeManager shared].currentPalette.primaryColor];
}

@end
