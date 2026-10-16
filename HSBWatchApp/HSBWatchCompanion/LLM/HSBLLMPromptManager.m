#import "HSBLLMPromptManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@implementation HSBLLMPromptManager

+ (instancetype)sharedManager {
    static HSBLLMPromptManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HSBLLMPromptManager alloc] init];
    });
    return instance;
}

- (NSArray<NSString *> *)quickPromptTagsForScenario:(HSBLLMTestScenarioType)scenario {
    if (scenario == HSBLLMTestScenarioTranslation) {
        return @[
            L(@"Translate 'The moon is beautiful tonight'", @"翻译: '今晚月色真美'"),
            L(@"Translate: 'Artificial Intelligence guides future'", @"翻译: '人工智能指引未来'"),
            L(@"Translate: 'Enjoy coding!'", @"翻译: '祝你配对编程愉快！'")
        ];
    } else if (scenario == HSBLLMTestScenarioWebControl) {
        return @[
            L(@"Turn background to soft red", @"电视网页背景变成柔和红"),
            L(@"Hide page header container", @"隐藏电视网页的所有导航栏"),
            L(@"Display an alert dialog", @"在电视上弹出一个 Hello 对话框"),
            L(@"Scroll down one screen", @"平滑向下滚动一屏")
        ];
    } else {
        return @[
            L(@"How to pair Apple TV?", @"如何连接配对 Apple TV？"),
            L(@"Remote unresponsive troubleshoot", @"电视按键无响应如何排查？"),
            L(@"What is dual-mode mechanism?", @"双模遥控核心机制是什么？"),
            L(@"Touchpad 5.5x gestures", @"微操触控板手势操作技巧")
        ];
    }
}

- (NSString *)promptTextForScenario:(HSBLLMTestScenarioType)scenario atIndex:(NSInteger)index {
    NSArray *prompts = nil;
    if (scenario == HSBLLMTestScenarioTranslation) {
        prompts = @[
            @"今晚月色真美，适合去散散步。",
            @"Artificial Intelligence will guide the future of human-machine interaction.",
            @"Enjoy pair programming with your smart assistant!"
        ];
    } else if (scenario == HSBLLMTestScenarioWebControl) {
        prompts = @[
            @"让电视网页的背景变成柔和红",
            @"隐藏当前网页的 header 头部导航栏",
            @"alert('糖葫芦遥控器：端侧智能验证成功！');",
            @"平滑向下滚动一屏"
        ];
    } else {
        prompts = @[
            @"如何连接配对 Apple TV？",
            @"电视按键无响应如何排查？",
            @"双模遥控核心机制是什么？",
            @"微操触控板手势操作技巧"
        ];
    }
    if (index >= 0 && index < prompts.count) {
        return prompts[index];
    }
    return @"";
}

- (NSString *)placeholderTextForScenario:(HSBLLMTestScenarioType)scenario {
    if (scenario == HSBLLMTestScenarioTranslation) {
        return L(@"Type text here to request translation...", @"在此处输入需要进行端侧 AI 同声传译的中文或英文内容...");
    } else if (scenario == HSBLLMTestScenarioWebControl) {
        return L(@"Describe the control action to generate and run JS script on TV...", @"在此处用自然语言描述电视控制指令（如：让背景变红、隐藏标题栏），AI 将自动生成脚本控制电视网页...");
    } else {
        return L(@"Ask Tanghulu AI Assistant anything about Apple TV and smart remote control...", @"向糖葫芦智能助手提问关于 Apple TV 遥控、电视网页浏览、网络连接的任何问题...");
    }
}

- (NSString *)systemPromptForScenario:(HSBLLMTestScenarioType)scenario {
    if (scenario == HSBLLMTestScenarioTranslation) {
        return @"你是一个精准的翻译助手。只输出最终的翻译结果，不要任何多余的解释、Markdown 或标注。";
    } else if (scenario == HSBLLMTestScenarioWebControl) {
        return @"你是一个前端开发助手。只输出纯 JavaScript 代码，不要任何 Markdown 格式(如 ```javascript) 或解释。";
    } else {
        return @"你是一个专业的客厅智能遥控管家。回答用户关于 Apple TV 和电视控制的问题。";
    }
}

- (NSString *)enhancedUserPromptForScenario:(HSBLLMTestScenarioType)scenario
                                 userPrompt:(NSString *)userPrompt
                             sourceLanguage:(NSString *)sourceLang
                             targetLanguage:(NSString *)targetLang {
    if (scenario == HSBLLMTestScenarioTranslation) {
        NSString *sourceStr = [sourceLang isEqualToString:@"自动识别"] ? @"自动识别语言" : (sourceLang ?: @"自动识别语言");
        NSString *targetStr = targetLang ?: @"中文";
        return [NSString stringWithFormat:@"请将下面这句话从【%@】翻译成【%@】：\n%@", sourceStr, targetStr, userPrompt];
    } else if (scenario == HSBLLMTestScenarioWebControl) {
        return [NSString stringWithFormat:@"请写一段 JavaScript 代码来实现这个需求：%@", userPrompt];
    } else {
        return userPrompt;
    }
}

- (NSArray<NSString *> *)supportedLanguagesForSource:(BOOL)isSource {
    if (isSource) {
        return @[@"自动识别", @"中文", @"英文", @"日文", @"韩文", @"法文", @"德文"];
    } else {
        return @[@"中文", @"英文", @"日文", @"韩文", @"法文", @"德文"];
    }
}

- (NSDictionary<NSString *, NSString *> *)languageMapping {
    return @{
        @"自动识别": @"Auto",
        @"中文": @"Chinese",
        @"英文": @"English",
        @"日文": @"Japanese",
        @"韩文": @"Korean",
        @"法文": @"French",
        @"德文": @"German",
        @"西班牙文": @"Spanish",
        @"俄文": @"Russian"
    };
}

- (NSString *)languageKeyForName:(NSString *)name {
    return [self languageMapping][name] ?: name;
}

- (NSString *)languageNameForKey:(NSString *)key {
    for (NSString *name in [self languageMapping]) {
        if ([[self languageMapping][name] isEqualToString:key]) {
            return name;
        }
    }
    return key;
}

@end
