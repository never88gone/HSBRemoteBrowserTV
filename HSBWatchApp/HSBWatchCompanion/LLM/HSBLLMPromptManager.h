#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HSBLLMTestScenarioType) {
    HSBLLMTestScenarioTranslation = 0,
    HSBLLMTestScenarioWebControl = 1,
    HSBLLMTestScenarioSmartButler = 2
};

@interface HSBLLMPromptManager : NSObject

+ (instancetype)sharedManager;

- (NSArray<NSString *> *)quickPromptTagsForScenario:(HSBLLMTestScenarioType)scenario;
- (NSString *)promptTextForScenario:(HSBLLMTestScenarioType)scenario atIndex:(NSInteger)index;
- (NSString *)placeholderTextForScenario:(HSBLLMTestScenarioType)scenario;

- (NSString *)systemPromptForScenario:(HSBLLMTestScenarioType)scenario;
- (NSString *)enhancedUserPromptForScenario:(HSBLLMTestScenarioType)scenario
                                 userPrompt:(NSString *)userPrompt
                             sourceLanguage:(NSString *)sourceLang
                             targetLanguage:(NSString *)targetLang;

- (NSArray<NSString *> *)supportedLanguagesForSource:(BOOL)isSource;
- (NSString *)languageKeyForName:(NSString *)name;
- (NSString *)languageNameForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
