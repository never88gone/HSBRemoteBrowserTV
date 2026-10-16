#import "HSBLocalLLMManager.h"
#import <CoreML/CoreML.h>
#import <NaturalLanguage/NaturalLanguage.h>
#import "HSBWatchCompanion-Swift.h"
#import "HSBBuiltInAIEngine.h"
#import "HSBCustomLLMAPIService.h"
#import "HSBLocalLLMDownloadService.h"

@implementation HSBLocalLLMModel
- (instancetype)initWithId:(NSString *)modelId name:(NSString *)name description:(NSString *)description url:(NSURL *)url {
    self = [super init];
    if (self) {
        _modelId = modelId;
        _name = name;
        _modelDescription = description;
        _url = url;
        _status = HSBLocalLLMDownloadStatusNone;
        _downloadProgress = 0.0;
        _isActive = NO;
        _isJSActive = NO;
    }
    return self;
}
@end

@interface HSBLocalLLMManager ()
@property (nonatomic, strong) NSArray<HSBLocalLLMModel *> *models;
@property (nonatomic, assign) BOOL isPrewarming;
@end

@implementation HSBLocalLLMManager

+ (instancetype)shared {
    static HSBLocalLLMManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[HSBLocalLLMManager alloc] init];
    });
    return sharedInstance;
}

+ (BOOL)useAppleTranslation {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HSBTranslationUseAppleKey];
}

+ (void)setUseAppleTranslation:(BOOL)use {
    [[NSUserDefaults standardUserDefaults] setBool:use forKey:HSBTranslationUseAppleKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)translationSystemPrompt {
    return [self translationSystemPromptWithSource:nil target:nil];
}

+ (NSString *)translationSystemPromptWithSource:(nullable NSString *)source target:(nullable NSString *)target {
    if (!source || source.length == 0) {
        source = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationSourceLanguage"] ?: @"Auto";
    }
    if (!target || target.length == 0) {
        target = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
    }
    
    NSDictionary *langMap = @{
        @"Auto": @"Auto Detect", @"auto": @"Auto Detect",
        @"Chinese": @"Chinese", @"zh": @"Chinese", @"zh-CN": @"Chinese", @"zh-TW": @"Chinese (Traditional)",
        @"English": @"English", @"en": @"English",
        @"Japanese": @"Japanese", @"ja": @"Japanese",
        @"Korean": @"Korean", @"ko": @"Korean",
        @"French": @"French", @"fr": @"French",
        @"German": @"German", @"de": @"German",
        @"Spanish": @"Spanish", @"es": @"Spanish",
        @"Russian": @"Russian", @"ru": @"Russian"
    };
    
    NSString *sourceEng = langMap[source] ?: source;
    NSString *targetEng = langMap[target] ?: target;
    
    if ([source isEqualToString:@"Auto"] || [source isEqualToString:@"auto"]) {
        if ([target isEqualToString:@"Chinese"] || [target isEqualToString:@"zh"] || [target isEqualToString:@"zh-CN"]) {
            return @"You are a professional translator. Translate the following text. If it is English, translate it into Chinese. If it is Chinese, translate it into English. Output ONLY the translation without any introduction or notes.";
        } else {
            return [NSString stringWithFormat:@"You are a professional translator. Translate the following text into %@. If it is already in %@, translate it into Chinese. Output ONLY the translation without any introduction or notes.", targetEng, targetEng];
        }
    } else {
        if ([source isEqualToString:target]) {
            return [NSString stringWithFormat:@"You are a professional translator. Output the input text as is in %@. Output ONLY the text without any introduction or notes.", targetEng];
        }
        return [NSString stringWithFormat:@"You are a professional translator. Translate the following text from %@ into %@. Output ONLY the translation without any introduction or notes.", sourceEng, targetEng];
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupDefaultModels];
    }
    return self;
}

#pragma mark - Custom API Static Delegation

+ (BOOL)useCustomAPI { return [HSBCustomLLMAPIService useCustomAPI]; }
+ (void)setUseCustomAPI:(BOOL)use { [HSBCustomLLMAPIService setUseCustomAPI:use]; }
+ (NSString *)customAPIEndpoint { return [HSBCustomLLMAPIService customAPIEndpoint]; }
+ (void)setCustomAPIEndpoint:(NSString *)endpoint { [HSBCustomLLMAPIService setCustomAPIEndpoint:endpoint]; }
+ (NSString *)customAPIKey { return [HSBCustomLLMAPIService customAPIKey]; }
+ (void)setCustomAPIKey:(NSString *)key { [HSBCustomLLMAPIService setCustomAPIKey:key]; }
+ (NSString *)customAPIModel { return [HSBCustomLLMAPIService customAPIModel]; }
+ (void)setCustomAPIModel:(NSString *)model { [HSBCustomLLMAPIService setCustomAPIModel:model]; }

- (BOOL)isBuiltInEngineActive {
    if ([HSBLocalLLMManager useCustomAPI]) return NO;
    return (self.activeModel == nil || !self.activeModel.isActive);
}

- (NSString *)currentEngineDisplayName {
    if ([HSBLocalLLMManager useCustomAPI]) {
        return [NSString stringWithFormat:@"自定义大模型 API (%@)", [HSBLocalLLMManager customAPIModel]];
    }
    if (!self.isBuiltInEngineActive && self.activeModel) {
        return [NSString stringWithFormat:@"MLX 物理大模型 (%@)", self.activeModel.name];
    }
    return @"内置端侧智能引擎 (开箱即用)";
}

#pragma mark - Models Setup

- (void)setupDefaultModels {
    NSMutableArray *allModels = [NSMutableArray array];
    
    NSArray *builtInConfigs = @[
        @{
            @"id": @"mlx-community/Qwen1.5-0.5B-Chat-4bit",
            @"name": @"Qwen1.5-0.5B (官方推荐)",
            @"desc": @"轻量多语言通识模型，支持中英文同声传译与日常对话，耗费内存极低 (约 350MB)。",
            @"url": @"https://hf-mirror.com/mlx-community/Qwen1.5-0.5B-Chat-4bit/resolve/main/tokenizer.json"
        },
        @{
            @"id": @"mlx-community/SmolLM-135M-Instruct-4bit",
            @"name": @"SmolLM-135M (极速体验)",
            @"desc": @"超轻量极致模型，下载极快，硬件内存占用低 (约 90MB)，适合低功耗场景快速体验。",
            @"url": @"https://hf-mirror.com/mlx-community/SmolLM-135M-Instruct-4bit/resolve/main/tokenizer.json"
        },
        @{
            @"id": @"mlx-community/gemma-2-2b-it-4bit",
            @"name": @"Gemma-2-2B-IT (深度推理)",
            @"desc": @"Google 深度指令遵循模型，适合前端网页复杂 JS 控制脚本生成 (约 1.2GB)。",
            @"url": @"https://hf-mirror.com/mlx-community/gemma-2-2b-it-4bit/resolve/main/tokenizer.json"
        }
    ];
    
    for (NSDictionary *info in builtInConfigs) {
        [allModels addObject:[[HSBLocalLLMModel alloc] initWithId:info[@"id"]
                                                            name:info[@"name"]
                                                     description:info[@"desc"]
                                                             url:[NSURL URLWithString:info[@"url"]]]];
    }
    
    NSArray *customList = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSBLocalLLM_CustomModelsList"];
    for (NSDictionary *dict in customList) {
        NSString *mId = dict[@"modelId"];
        NSString *name = dict[@"name"];
        NSString *desc = dict[@"description"];
        NSString *originalUrl = dict[@"url"];
        if (mId && name) {
            BOOL alreadyExists = NO;
            for (HSBLocalLLMModel *existing in allModels) {
                if ([existing.modelId.lowercaseString isEqualToString:mId.lowercaseString]) {
                    alreadyExists = YES;
                    break;
                }
            }
            if (!alreadyExists) {
                NSURL *dummyUrl = (originalUrl && originalUrl.length > 0) ? [NSURL URLWithString:originalUrl] : [NSURL URLWithString:[NSString stringWithFormat:@"https://hf-mirror.com/%@/resolve/main/tokenizer.json", mId]];
                [allModels addObject:[[HSBLocalLLMModel alloc] initWithId:mId name:name description:desc url:dummyUrl]];
            }
        }
    }
    
    self.models = [allModels copy];
    
    NSString *activeModelId = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBLocalLLM_ActiveModelId"];
    if ([activeModelId isEqualToString:@"qwen1.5-0.5b"]) activeModelId = @"mlx-community/Qwen1.5-0.5B-Chat-4bit";
    if ([activeModelId isEqualToString:@"gemma-2b-it"] || [activeModelId isEqualToString:@"mlx-community/gemma-2b-it-4bit"]) activeModelId = @"mlx-community/gemma-2-2b-it-4bit";
    
    NSString *jsActiveModelId = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBLocalLLM_JSActiveModelId"];
    if ([jsActiveModelId isEqualToString:@"qwen1.5-0.5b"]) jsActiveModelId = @"mlx-community/Qwen1.5-0.5B-Chat-4bit";
    if ([jsActiveModelId isEqualToString:@"gemma-2b-it"] || [jsActiveModelId isEqualToString:@"mlx-community/gemma-2b-it-4bit"]) jsActiveModelId = @"mlx-community/gemma-2-2b-it-4bit";
    
    __block HSBLocalLLMModel *modelToActivate = nil;
    __block HSBLocalLLMModel *jsModelToActivate = nil;
    
    for (HSBLocalLLMModel *model in self.models) {
        NSString *cacheKey = [NSString stringWithFormat:@"HSBLocalLLM_Downloaded_%@", model.modelId];
        BOOL isPhysicallyDownloaded = [[HSBMLXLLMEngine shared] isModelDownloaded:model.modelId];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:cacheKey] || isPhysicallyDownloaded) {
            model.status = HSBLocalLLMDownloadStatusFinished;
            model.downloadProgress = 1.0;
            
            if (![[NSUserDefaults standardUserDefaults] boolForKey:cacheKey]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:cacheKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            if (activeModelId && [model.modelId isEqualToString:activeModelId]) {
                modelToActivate = model;
            } else if (!modelToActivate) {
                modelToActivate = model;
            }
            
            if (jsActiveModelId && [model.modelId isEqualToString:jsActiveModelId]) {
                jsModelToActivate = model;
            }
        }
    }
    
    if (modelToActivate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self activateModel:modelToActivate];
        });
    }
    if (jsModelToActivate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self activateJSModel:jsModelToActivate];
        });
    }
}

- (NSArray<HSBLocalLLMModel *> *)availableModels {
    return self.models;
}

#pragma mark - Download & Cache Management

- (void)downloadModel:(HSBLocalLLMModel *)model progress:(HSBLocalLLMProgressBlock)progress completion:(HSBLocalLLMCompletionBlock)completion {
    [[HSBLocalLLMDownloadService sharedService] downloadModel:model progress:progress completion:completion];
}

- (BOOL)deleteModelCacheForModel:(HSBLocalLLMModel *)model {
    if (model.isActive) [self deactivateModel:model];
    if (model.isJSActive) [self deactivateJSModel:model];
    return [[HSBLocalLLMDownloadService sharedService] deleteModelCacheForModel:model];
}

- (void)pauseDownloadModel:(HSBLocalLLMModel *)model {
    model.status = HSBLocalLLMDownloadStatusPaused;
}

#pragma mark - Activation & Prewarming

- (void)activateModel:(HSBLocalLLMModel *)model {
    if (model.status != HSBLocalLLMDownloadStatusFinished) return;
    
    NSLog(@"[HSBLocalLLM] Physical LLM Engine Activated: %@", model.name);
    for (HSBLocalLLMModel *m in self.models) {
        m.isActive = (m == model);
    }
    self.activeModel = model;
    
    [[NSUserDefaults standardUserDefaults] setObject:model.modelId forKey:@"HSBLocalLLM_ActiveModelId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
    [self prewarmActiveModel];
}

- (void)prewarmActiveModel {
    if (!self.activeModel) return;
    
    BOOL isDownloaded = [[HSBMLXLLMEngine shared] isModelDownloaded:self.activeModel.modelId];
    if (!isDownloaded) {
        NSLog(@"[HSBLocalLLM] Active model '%@' not yet on disk. Skip prewarming.", self.activeModel.modelId);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLM_PrewarmingFinishedNotification" object:self.activeModel];
        });
        return;
    }
    
    if (self.isPrewarming) return;
    self.isPrewarming = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLM_PrewarmingStartedNotification" object:self.activeModel];
    HSBLocalLLMModel *targetModel = self.activeModel;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[HSBMLXLLMEngine shared] loadAndActivateModelWithModelId:targetModel.modelId callback:^(NSString * _Nonnull logText, double progress) {
            if (progress >= 1.0 || progress < 0.0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.isPrewarming = NO;
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLM_PrewarmingFinishedNotification" object:targetModel];
                });
            }
        }];
    });
}

- (void)deactivateModel:(HSBLocalLLMModel *)model {
    if (!model.isActive) return;
    model.isActive = NO;
    if (self.activeModel == model) self.activeModel = nil;
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HSBLocalLLM_ActiveModelId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
}

- (void)activateJSModel:(HSBLocalLLMModel *)model {
    if (model.status != HSBLocalLLMDownloadStatusFinished) return;
    for (HSBLocalLLMModel *m in self.models) {
        m.isJSActive = (m == model);
    }
    self.jsActiveModel = model;
    
    [[NSUserDefaults standardUserDefaults] setObject:model.modelId forKey:@"HSBLocalLLM_JSActiveModelId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
}

- (void)deactivateJSModel:(HSBLocalLLMModel *)model {
    if (!model.isJSActive) return;
    model.isJSActive = NO;
    if (self.jsActiveModel == model) self.jsActiveModel = nil;
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HSBLocalLLM_JSActiveModelId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
}

- (BOOL)addCustomModelWithName:(NSString *)name repoId:(NSString *)repoId error:(NSError **)error {
    NSString *trimmedName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *trimmedInput = [repoId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (trimmedName.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"com.hsb.llm" code:-100 userInfo:@{NSLocalizedDescriptionKey: @"模型名称不能为空。"}];
        return NO;
    }
    if (trimmedInput.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"com.hsb.llm" code:-101 userInfo:@{NSLocalizedDescriptionKey: @"模型下载地址不能为空。"}];
        return NO;
    }
    
    NSString *parsedModelId = nil;
    NSString *parsedEndpoint = nil;
    NSString *parsedUrl = nil;
    
    if ([trimmedInput hasPrefix:@"http://"] || [trimmedInput hasPrefix:@"https://"]) {
        NSURL *nsurl = [NSURL URLWithString:trimmedInput];
        if (!nsurl || !nsurl.scheme || !nsurl.host) {
            if (error) *error = [NSError errorWithDomain:@"com.hsb.llm" code:-102 userInfo:@{NSLocalizedDescriptionKey: @"无效的下载 URL。"}];
            return NO;
        }
        parsedEndpoint = [NSString stringWithFormat:@"%@://%@%@", nsurl.scheme, nsurl.host, nsurl.port ? [NSString stringWithFormat:@":%@", nsurl.port] : @""];
        parsedUrl = trimmedInput;
        
        NSString *path = nsurl.path;
        NSRange resolveRange = [path rangeOfString:@"/resolve/" options:NSCaseInsensitiveSearch];
        NSString *repoPath = (resolveRange.location != NSNotFound) ? [path substringToIndex:resolveRange.location] : path;
        repoPath = [repoPath stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
        NSArray *pathComponents = [repoPath componentsSeparatedByString:@"/"];
        if (pathComponents.count != 2 || [pathComponents[0] length] == 0 || [pathComponents[1] length] == 0) {
            if (error) *error = [NSError errorWithDomain:@"com.hsb.llm" code:-102 userInfo:@{NSLocalizedDescriptionKey: @"无法从 URL 中解析出有效的仓库信息。"}];
            return NO;
        }
        parsedModelId = repoPath;
    } else {
        NSArray *parts = [trimmedInput componentsSeparatedByString:@"/"];
        if (parts.count != 2 || [parts[0] length] == 0 || [parts[1] length] == 0) {
            if (error) *error = [NSError errorWithDomain:@"com.hsb.llm" code:-102 userInfo:@{NSLocalizedDescriptionKey: @"格式不正确，应形如: 作者/项目名"}];
            return NO;
        }
        parsedModelId = trimmedInput;
        parsedEndpoint = @"https://hf-mirror.com";
        parsedUrl = [NSString stringWithFormat:@"https://hf-mirror.com/%@/resolve/main/tokenizer.json", parsedModelId];
    }
    
    for (HSBLocalLLMModel *m in self.models) {
        if ([m.modelId.lowercaseString isEqualToString:parsedModelId.lowercaseString]) {
            if (error) *error = [NSError errorWithDomain:@"com.hsb.llm" code:-103 userInfo:@{NSLocalizedDescriptionKey: @"该大模型已存在于您的模型列表中。"}];
            return NO;
        }
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *existing = [defaults objectForKey:@"HSBLocalLLM_CustomModelsList"];
    NSMutableArray *customList = existing ? [existing mutableCopy] : [NSMutableArray array];
    
    [customList addObject:@{
        @"modelId": parsedModelId,
        @"name": trimmedName,
        @"description": @"用户自定义添加的 MLX 格式模型。",
        @"endpoint": parsedEndpoint,
        @"url": parsedUrl
    }];
    [defaults setObject:customList forKey:@"HSBLocalLLM_CustomModelsList"];
    [defaults setObject:parsedEndpoint forKey:[NSString stringWithFormat:@"HSBLocalLLM_ModelEndpoint_%@", parsedModelId]];
    [defaults synchronize];
    
    [self setupDefaultModels];
    return YES;
}

#pragma mark - Message Processing

- (void)processMessage:(NSString *)message systemPrompt:(NSString *)systemPrompt completion:(HSBLocalLLMMessageCompletion)completion {
    [self processMessage:message systemPrompt:systemPrompt type:0 completion:completion];
}

- (void)processMessage:(NSString *)message systemPrompt:(NSString *)systemPrompt type:(NSInteger)type completion:(HSBLocalLLMMessageCompletion)completion {
    if ([HSBLocalLLMManager useCustomAPI]) {
        __weak typeof(self) weakSelf = self;
        [[HSBCustomLLMAPIService sharedService] processMessage:message systemPrompt:systemPrompt type:type completion:completion fallbackHandler:^{
            [[HSBBuiltInAIEngine sharedEngine] processMessage:message systemPrompt:systemPrompt type:type completion:completion];
        }];
        return;
    }
    
    if (self.isBuiltInEngineActive) {
        [[HSBBuiltInAIEngine sharedEngine] processMessage:message systemPrompt:systemPrompt type:type completion:completion];
        return;
    }
    
    if (type == 1 && [HSBLocalLLMManager useAppleTranslation]) {
        NSString *sourceLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationSourceLanguage"] ?: @"Auto";
        NSString *targetLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
        
        NSArray *components = [message componentsSeparatedByString:@"\n"];
        NSString *rawText = components.count > 0 ? components.lastObject : message;
        
        [HSBAppleTranslationHelper translateWithText:rawText sourceLanguage:sourceLang targetLanguage:targetLang completion:^(NSString * _Nullable translatedText, NSError * _Nullable error) {
            if (error) {
                if (self.activeModel) {
                    NSDictionary *map = @{ @"Auto": @"自动识别语言", @"Chinese": @"中文", @"English": @"英文", @"Japanese": @"日文", @"Korean": @"韩文", @"French": @"法文", @"German": @"德文", @"Spanish": @"西班牙文", @"Russian": @"俄文" };
                    NSString *sourceStr = map[sourceLang] ?: @"自动识别语言";
                    NSString *targetStr = map[targetLang] ?: @"中文";
                    NSString *fallbackSystemPrompt = @"你是一个精准的翻译助手。只输出最终的翻译结果，不要任何多余的解释、Markdown 或标注。";
                    NSString *fallbackUserPrompt = [NSString stringWithFormat:@"请将下面这句话从【%@】翻译成【%@】：\n%@", sourceStr, targetStr, rawText];
                    
                    [[HSBMLXLLMEngine shared] generateWithMLXWithSystemPrompt:fallbackSystemPrompt userPrompt:fallbackUserPrompt modelId:self.activeModel.modelId callback:^(NSString * _Nonnull partialResponse, BOOL isFinished) {
                        if (completion) {
                            if ([partialResponse hasPrefix:@"❌"] && isFinished) {
                                [[HSBBuiltInAIEngine sharedEngine] processMessage:rawText systemPrompt:systemPrompt type:1 completion:completion];
                                return;
                            }
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(partialResponse, isFinished);
                            });
                        }
                    }];
                } else {
                    [[HSBBuiltInAIEngine sharedEngine] processMessage:rawText systemPrompt:systemPrompt type:1 completion:completion];
                }
            } else {
                if (completion) completion(translatedText ?: @"", YES);
            }
        }];
        return;
    }
    
    HSBLocalLLMModel *targetModel = (type == 2) ? (self.jsActiveModel ?: self.activeModel) : self.activeModel;
    if (!targetModel) {
        [[HSBBuiltInAIEngine sharedEngine] processMessage:message systemPrompt:systemPrompt type:type completion:completion];
        return;
    }
    
    BOOL isJSTask = (type == 2) || [systemPrompt containsString:@"JavaScript"] || [systemPrompt containsString:@"JS"] || [systemPrompt containsString:@"code"];
    
    [[HSBMLXLLMEngine shared] generateWithMLXWithSystemPrompt:systemPrompt userPrompt:message modelId:targetModel.modelId callback:^(NSString * _Nonnull partialResponse, BOOL isFinished) {
        if (completion) {
            if ([partialResponse hasPrefix:@"❌"] && isFinished) {
                [[HSBBuiltInAIEngine sharedEngine] processMessage:message systemPrompt:systemPrompt type:type completion:completion];
                return;
            }
            NSString *finalResponse = isJSTask ? [[HSBBuiltInAIEngine sharedEngine] cleanJSCode:partialResponse] : partialResponse;
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(finalResponse, isFinished);
            });
        }
    }];
}

- (void)cancelInference {
    [[HSBMLXLLMEngine shared] cancelCurrentInference];
}

@end
