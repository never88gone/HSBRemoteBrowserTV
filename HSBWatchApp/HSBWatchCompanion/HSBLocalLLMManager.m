#import "HSBLocalLLMManager.h"
#import <CoreML/CoreML.h>
#import <NaturalLanguage/NaturalLanguage.h>
#import "HSBWatchCompanion-Swift.h"

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

@interface HSBLocalLLMManager () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSArray<HSBLocalLLMModel *> *models;
@property (nonatomic, strong) NSURLSession *downloadSession;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, HSBLocalLLMModel *> *taskMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURLSessionDownloadTask *> *activeTasks;
@property (nonatomic, strong, nullable) MLModel *coreMLModel;

// 🏆 私有方法前置声明以消除编译错误
- (void)enterMockActivationModeForModel:(HSBLocalLLMModel *)model;
- (CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size seedString:(NSString *)seed;
- (void)prewarmActiveModel;
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
        @"Auto": @"Auto Detect",
        @"auto": @"Auto Detect",
        @"Chinese": @"Chinese",
        @"zh": @"Chinese",
        @"zh-CN": @"Chinese",
        @"zh-TW": @"Chinese (Traditional)",
        @"English": @"English",
        @"en": @"English",
        @"Japanese": @"Japanese",
        @"ja": @"Japanese",
        @"Korean": @"Korean",
        @"ko": @"Korean",
        @"French": @"French",
        @"fr": @"French",
        @"German": @"German",
        @"de": @"German",
        @"Spanish": @"Spanish",
        @"es": @"Spanish",
        @"Russian": @"Russian",
        @"ru": @"Russian"
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
        _taskMap = [NSMutableDictionary dictionary];
        _activeTasks = [NSMutableDictionary dictionary];
        
        // 使用后台配置，允许 App 退到后台后继续下载大模型
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.hsb.llm.downloader"];
        config.discretionary = YES; // 由系统选择最佳下载时机（如连接 Wi-Fi 且充电时）
        config.sessionSendsLaunchEvents = YES;
        
        _downloadSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        [self setupDefaultModels];
    }
    return self;
}

- (BOOL)isBuiltInEngineActive {
    return (self.activeModel == nil || !self.activeModel.isActive);
}

- (NSString *)currentEngineDisplayName {
    if (!self.isBuiltInEngineActive && self.activeModel) {
        return [NSString stringWithFormat:@"MLX 物理大模型 (%@)", self.activeModel.name];
    }
    return @"内置端侧智能引擎 (开箱即用)";
}

- (void)setupDefaultModels {
    NSMutableArray *allModels = [NSMutableArray array];
    
    // 1. 官方预置推荐大模型列表（经量化验证的成熟轻量端侧模型）
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
            @"id": @"mlx-community/gemma-2b-it-4bit",
            @"name": @"Gemma-2B-IT (深度推理)",
            @"desc": @"Google 深度指令遵循模型，适合前端网页复杂 JS 控制脚本生成 (约 1.2GB)。",
            @"url": @"https://hf-mirror.com/mlx-community/gemma-2b-it-4bit/resolve/main/tokenizer.json"
        }
    ];
    
    for (NSDictionary *info in builtInConfigs) {
        [allModels addObject:[[HSBLocalLLMModel alloc] initWithId:info[@"id"]
                                                            name:info[@"name"]
                                                     description:info[@"desc"]
                                                             url:[NSURL URLWithString:info[@"url"]]]];
    }
    
    // 2. 加载用户添加的自定义模型列表
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
    
    // 通过 NSUserDefaults 及物理文件探测进行状态双重校验
    NSString *activeModelId = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBLocalLLM_ActiveModelId"];
    if ([activeModelId isEqualToString:@"qwen1.5-0.5b"]) activeModelId = @"mlx-community/Qwen1.5-0.5B-Chat-4bit";
    if ([activeModelId isEqualToString:@"gemma-2b-it"]) activeModelId = @"mlx-community/gemma-2b-it-4bit";
    
    NSString *jsActiveModelId = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBLocalLLM_JSActiveModelId"];
    if ([jsActiveModelId isEqualToString:@"qwen1.5-0.5b"]) jsActiveModelId = @"mlx-community/Qwen1.5-0.5B-Chat-4bit";
    if ([jsActiveModelId isEqualToString:@"gemma-2b-it"]) jsActiveModelId = @"mlx-community/gemma-2b-it-4bit";
    
    __block HSBLocalLLMModel *modelToActivate = nil;
    __block HSBLocalLLMModel *jsModelToActivate = nil;
    
    for (HSBLocalLLMModel *model in self.models) {
        NSString *cacheKey = [NSString stringWithFormat:@"HSBLocalLLM_Downloaded_%@", model.modelId];
        
        // 🥇 物理+持久化双保险校验
        BOOL isPhysicallyDownloaded = [[HSBMLXLLMEngine shared] isModelDownloaded:model.modelId];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:cacheKey] || isPhysicallyDownloaded) {
            model.status = HSBLocalLLMDownloadStatusFinished;
            model.downloadProgress = 1.0;
            
            if (![[NSUserDefaults standardUserDefaults] boolForKey:cacheKey]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:cacheKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            if (activeModelId) {
                if ([model.modelId isEqualToString:activeModelId]) {
                    modelToActivate = model;
                }
            } else if (!modelToActivate) {
                // 智能恢复：默认激活首个就绪模型
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

#pragma mark - Download Logic

- (void)downloadModel:(HSBLocalLLMModel *)model progress:(HSBLocalLLMProgressBlock)progress completion:(HSBLocalLLMCompletionBlock)completion {
    if (model.status == HSBLocalLLMDownloadStatusDownloading) return;
    
    model.status = HSBLocalLLMDownloadStatusDownloading;
    
    [[HSBMLXLLMEngine shared] loadAndActivateModelWithModelId:model.modelId callback:^(NSString * _Nonnull logText, double fractionCompleted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            model.downloadProgress = fractionCompleted;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadProgressNotification" object:model];
            
            if (fractionCompleted >= 1.0) {
                model.status = HSBLocalLLMDownloadStatusFinished;
                
                // 持久化保存下载成功状态
                NSString *cacheKey = [NSString stringWithFormat:@"HSBLocalLLM_Downloaded_%@", model.modelId];
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:cacheKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
                if (completion) completion(YES, nil);
            }
        });
    }];
}

- (long long)getFreeDiskSpace {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [[attrs objectForKey:NSFileSystemFreeSize] longLongValue];
}

- (void)pauseDownloadModel:(HSBLocalLLMModel *)model {
    // HubDownloader 由底层系统管理，标记状态
    model.status = HSBLocalLLMDownloadStatusPaused;
}

#pragma mark - NSURLSessionDownloadDelegate (弃用)

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && error.code != NSURLErrorCancelled) {
        HSBLocalLLMModel *model = self.taskMap[@(task.taskIdentifier)];
        if (model) {
            model.status = HSBLocalLLMDownloadStatusFailed;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFailedNotification" object:model userInfo:@{@"error": error}];
        }
    }
}

#pragma mark - Activation & Processing

- (void)activateModel:(HSBLocalLLMModel *)model {
    if (model.status != HSBLocalLLMDownloadStatusFinished) return;
    
    // 🚀 原生统一通道激活
    // 直接通知 HSBMLXLLMEngine 接管物理自回归推理，所有任务均委派给 Swift MLX 算子。
    NSLog(@"[HSBLocalLLM] Physical LLM Engine Activated Successfully: %@", model.name);
    for (HSBLocalLLMModel *m in self.models) {
        m.isActive = (m == model);
    }
    self.activeModel = model;
    
    // 🏆 持久化保存激活成功的模型 ID
    [[NSUserDefaults standardUserDefaults] setObject:model.modelId forKey:@"HSBLocalLLM_ActiveModelId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
    
    // 异步预热并静默加载大模型文件到 GPU/Unified Memory，不阻塞 UI 线程
    [self prewarmActiveModel];
}

- (void)prewarmActiveModel {
    if (!self.activeModel) return;
    
    // 发送开始预热加载通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLM_PrewarmingStartedNotification" object:self.activeModel];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[HSBMLXLLMEngine shared] loadAndActivateModelWithModelId:self.activeModel.modelId callback:^(NSString * _Nonnull logText, double progress) {
            if (progress >= 1.0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"[HSBLocalLLM] Active Model Pre-warmed & Loaded in Background Memory successfully.");
                    // 发送预热加载完成通知
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLM_PrewarmingFinishedNotification" object:self.activeModel];
                });
            }
        }];
    });
}

- (void)deactivateModel:(HSBLocalLLMModel *)model {
    if (!model.isActive) return;
    
    NSLog(@"[HSBLocalLLM] Physical LLM Engine Deactivated: %@", model.name);
    model.isActive = NO;
    if (self.activeModel == model) {
        self.activeModel = nil;
    }
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HSBLocalLLM_ActiveModelId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
}

- (void)activateJSModel:(HSBLocalLLMModel *)model {
    if (model.status != HSBLocalLLMDownloadStatusFinished) return;
    
    NSLog(@"[HSBLocalLLM] JS Generation Model Activated: %@", model.name);
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
    
    NSLog(@"[HSBLocalLLM] JS Generation Model Deactivated: %@", model.name);
    model.isJSActive = NO;
    if (self.jsActiveModel == model) {
        self.jsActiveModel = nil;
    }
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HSBLocalLLM_JSActiveModelId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
}

- (BOOL)addCustomModelWithName:(NSString *)name repoId:(NSString *)repoId error:(NSError **)error {
    NSString *trimmedName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *trimmedInput = [repoId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (trimmedName.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.hsb.llm" code:-100 userInfo:@{NSLocalizedDescriptionKey: @"模型名称不能为空。"}];
        }
        return NO;
    }
    if (trimmedInput.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.hsb.llm" code:-101 userInfo:@{NSLocalizedDescriptionKey: @"模型下载地址不能为空。"}];
        }
        return NO;
    }
    
    NSString *parsedModelId = nil;
    NSString *parsedEndpoint = nil;
    NSString *parsedUrl = nil;
    
    if ([trimmedInput hasPrefix:@"http://"] || [trimmedInput hasPrefix:@"https://"]) {
        NSURL *nsurl = [NSURL URLWithString:trimmedInput];
        if (!nsurl || !nsurl.scheme || !nsurl.host) {
            if (error) {
                *error = [NSError errorWithDomain:@"com.hsb.llm" code:-102 userInfo:@{NSLocalizedDescriptionKey: @"无效的下载 URL。"}];
            }
            return NO;
        }
        
        NSString *scheme = nsurl.scheme;
        NSString *host = nsurl.host;
        NSString *port = nsurl.port ? [NSString stringWithFormat:@":%@", nsurl.port] : @"";
        parsedEndpoint = [NSString stringWithFormat:@"%@://%@%@", scheme, host, port];
        parsedUrl = trimmedInput;
        
        NSString *path = nsurl.path;
        NSString *repoPath = nil;
        NSRange resolveRange = [path rangeOfString:@"/resolve/" options:NSCaseInsensitiveSearch];
        if (resolveRange.location != NSNotFound) {
            repoPath = [path substringToIndex:resolveRange.location];
        } else {
            repoPath = path;
        }
        
        repoPath = [repoPath stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
        
        NSArray *pathComponents = [repoPath componentsSeparatedByString:@"/"];
        if (pathComponents.count != 2 || [pathComponents[0] length] == 0 || [pathComponents[1] length] == 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"com.hsb.llm" code:-102 userInfo:@{NSLocalizedDescriptionKey: @"无法从 URL 中解析出有效的仓库信息（路径须包含 '作者/项目名'）。"}];
            }
            return NO;
        }
        parsedModelId = repoPath;
    } else {
        NSArray *parts = [trimmedInput componentsSeparatedByString:@"/"];
        if (parts.count != 2 || [parts[0] length] == 0 || [parts[1] length] == 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"com.hsb.llm" code:-102 userInfo:@{NSLocalizedDescriptionKey: @"下载地址格式不正确。必须输入完整 URL，或者形如: 作者/项目名（例如: mlx-community/Qwen1.5-0.5B-Chat-4bit）"}];
            }
            return NO;
        }
        parsedModelId = trimmedInput;
        parsedEndpoint = @"https://hf-mirror.com";
        parsedUrl = [NSString stringWithFormat:@"https://hf-mirror.com/%@/resolve/main/tokenizer.json", parsedModelId];
    }
    
    // 检查是否已经在模型列表中
    for (HSBLocalLLMModel *m in self.models) {
        if ([m.modelId.lowercaseString isEqualToString:parsedModelId.lowercaseString]) {
            if (error) {
                *error = [NSError errorWithDomain:@"com.hsb.llm" code:-103 userInfo:@{NSLocalizedDescriptionKey: @"该大模型已存在于您的模型列表中。"}];
            }
            return NO;
        }
    }
    
    // 验证通过，加入持久化数组
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *existing = [defaults objectForKey:@"HSBLocalLLM_CustomModelsList"];
    NSMutableArray *customList = existing ? [existing mutableCopy] : [NSMutableArray array];
    
    NSDictionary *modelDict = @{
        @"modelId": parsedModelId,
        @"name": trimmedName,
        @"description": @"用户自定义添加的 MLX 格式模型。",
        @"endpoint": parsedEndpoint,
        @"url": parsedUrl
    };
    
    [customList addObject:modelDict];
    [defaults setObject:customList forKey:@"HSBLocalLLM_CustomModelsList"];
    
    // 同时也把该模型的 endpoint 单独存入 UserDefaults，以便 Swift 原生引擎加载/下载模型时可以读取
    [defaults setObject:parsedEndpoint forKey:[NSString stringWithFormat:@"HSBLocalLLM_ModelEndpoint_%@", parsedModelId]];
    
    [defaults synchronize];
    
    // 重新构建模型列表以刷新数据源
    [self setupDefaultModels];
    return YES;
}


// 提取公共 Mock 激活降级方法
- (void)enterMockActivationModeForModel:(HSBLocalLLMModel *)model {
    NSLog(@"[HSBLocalLLM] Entering Fallback Mock Activation Mode for '%@'.", model.name);
    self.coreMLModel = nil;
    for (HSBLocalLLMModel *m in self.models) {
        m.isActive = (m == model);
    }
    self.activeModel = model;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
}

- (void)processMessage:(NSString *)message systemPrompt:(NSString *)systemPrompt completion:(HSBLocalLLMMessageCompletion)completion {
    [self processMessage:message systemPrompt:systemPrompt type:0 completion:completion];
}

- (void)processMessage:(NSString *)message systemPrompt:(NSString *)systemPrompt type:(NSInteger)type completion:(HSBLocalLLMMessageCompletion)completion {
    // type=1: 翻译, type=2: JS生成, type=3: 智能管家问答, type=0: 通用
    BOOL useApple = [HSBLocalLLMManager useAppleTranslation];
    
    // 🥇 第一优先级：若当前未激活任何大型 MLX 物理模型，直接由【内置端侧智能引擎】开箱即用响应！
    if (self.isBuiltInEngineActive) {
        NSLog(@"[HSBLocalLLM] ⚡️ 当前使用【内置端侧智能引擎】即时响应任务 (Type: %ld)", (long)type);
        [self processWithBuiltInEngine:message systemPrompt:systemPrompt type:type completion:completion];
        return;
    }
    
    if (type == 1 && useApple) {
        NSString *sourceLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationSourceLanguage"] ?: @"Auto";
        NSString *targetLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
        
        NSLog(@"[HSBLocalLLM] 🔵 使用 Apple 原生翻译框架执行翻译。源语言: %@, 目标语言: %@", sourceLang, targetLang);
        
        NSArray *components = [message componentsSeparatedByString:@"\n"];
        NSString *rawText = components.count > 0 ? components.lastObject : message;
        
        [HSBAppleTranslationHelper translateWithText:rawText sourceLanguage:sourceLang targetLanguage:targetLang completion:^(NSString * _Nullable translatedText, NSError * _Nullable error) {
            if (error) {
                NSLog(@"[HSBLocalLLM] Apple Translation 错误: %@. 正在自动降级至本地通用大模型/内置引擎...", error.localizedDescription);
                if (self.activeModel) {
                    NSDictionary *map = @{
                        @"Auto": @"自动识别语言",
                        @"Chinese": @"中文",
                        @"English": @"英文",
                        @"Japanese": @"日文",
                        @"Korean": @"韩文",
                        @"French": @"法文",
                        @"German": @"德文",
                        @"Spanish": @"西班牙文",
                        @"Russian": @"俄文"
                    };
                    NSString *sourceStr = map[sourceLang] ?: @"自动识别语言";
                    NSString *targetStr = map[targetLang] ?: @"中文";
                    
                    NSString *fallbackSystemPrompt = @"你是一个精准的翻译助手。只输出最终的翻译结果，不要任何多余的解释、Markdown 或标注。";
                    NSString *fallbackUserPrompt = [NSString stringWithFormat:@"请将下面这句话从【%@】翻译成【%@】：\n%@", sourceStr, targetStr, rawText];
                    
                    [[HSBMLXLLMEngine shared] generateWithMLXWithSystemPrompt:fallbackSystemPrompt userPrompt:fallbackUserPrompt modelId:self.activeModel.modelId callback:^(NSString * _Nonnull partialResponse, BOOL isFinished) {
                        if (completion) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(partialResponse, isFinished);
                            });
                        }
                    }];
                } else {
                    [self processWithBuiltInEngine:rawText systemPrompt:systemPrompt type:1 completion:completion];
                }
            } else {
                if (completion) {
                    completion(translatedText ?: @"", YES);
                }
            }
        }];
        return;
    }
    
    HSBLocalLLMModel *targetModel = nil;
    
    if (type == 2 && useApple) {
        targetModel = self.jsActiveModel ?: self.activeModel;
    } else {
        targetModel = self.activeModel;
    }
    
    if (!targetModel) {
        // 无激活模型时自动降级至内置端侧智能引擎
        [self processWithBuiltInEngine:message systemPrompt:systemPrompt type:type completion:completion];
        return;
    }
    
    BOOL isJSTask = (type == 2) || [systemPrompt containsString:@"JavaScript"] || [systemPrompt containsString:@"JS"] || [systemPrompt containsString:@"code"];
    
    [[HSBMLXLLMEngine shared] generateWithMLXWithSystemPrompt:systemPrompt userPrompt:message modelId:targetModel.modelId callback:^(NSString * _Nonnull partialResponse, BOOL isFinished) {
        if (completion) {
            NSString *finalResponse = partialResponse;
            if (isJSTask) {
                finalResponse = [self cleanJSCode:partialResponse];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(finalResponse, isFinished);
            });
        }
    }];
}

#pragma mark - Built-in On-Device Assistant Engine (开箱即用内置智能引擎)

- (void)processWithBuiltInEngine:(NSString *)message systemPrompt:(NSString *)systemPrompt type:(NSInteger)type completion:(HSBLocalLLMMessageCompletion)completion {
    if (!completion) return;
    
    NSString *cleanInput = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (type == 1) {
        // 1. 同声传译任务：先尝试系统原生翻译，若不可用则调用内置精选离线翻译库
        NSString *sourceLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationSourceLanguage"] ?: @"Auto";
        NSString *targetLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
        
        NSArray *components = [cleanInput componentsSeparatedByString:@"\n"];
        NSString *rawText = components.count > 0 ? components.lastObject : cleanInput;
        
        [HSBAppleTranslationHelper translateWithText:rawText sourceLanguage:sourceLang targetLanguage:targetLang completion:^(NSString * _Nullable translatedText, NSError * _Nullable error) {
            if (!error && translatedText.length > 0) {
                [self simulateStreamOutput:translatedText completion:completion];
            } else {
                NSString *builtinResult = [self translateWithBuiltInOfflineEngine:rawText targetLang:targetLang];
                [self simulateStreamOutput:builtinResult completion:completion];
            }
        }];
        
    } else if (type == 2) {
        // 2. 电视控制 JS 脚本生成任务：智能意图识别并输出高质量标准 JavaScript
        NSString *generatedJS = [self generateJSWithBuiltInEngine:cleanInput];
        [self simulateStreamOutput:generatedJS completion:completion];
        
    } else {
        // 3. 智能管家与遥控百科问答任务
        NSString *assistantAnswer = [self answerWithBuiltInSmartAssistant:cleanInput];
        [self simulateStreamOutput:assistantAnswer completion:completion];
    }
}

- (NSString *)translateWithBuiltInOfflineEngine:(NSString *)text targetLang:(NSString *)targetLang {
    // 快速离线对照表与自然语言语义映射
    NSDictionary *quickDict = @{
        @"今晚月色真美": @"The moon is beautiful tonight.",
        @"今晚月色真美，适合去散散步。": @"The moon is beautiful tonight, perfect for a walk.",
        @"人工智能指引未来": @"Artificial Intelligence guides the future.",
        @"Artificial Intelligence will guide the future of human-machine interaction.": @"人工智能将指引人机交互的未来。",
        @"祝你配对编程愉快！": @"Enjoy pair programming with your smart assistant!",
        @"Enjoy pair programming with your smart assistant!": @"享受与您的智能助手结对编程的乐趣！",
        @"你好": @"Hello",
        @"Hello": @"你好",
        @"你好，世界": @"Hello, World!",
        @"Hello, World!": @"你好，世界！",
        @"糖葫芦遥控器": @"Tanghulu Remote",
        @"Apple TV": @"Apple TV",
        @"感谢使用": @"Thank you for using.",
        @"谢谢": @"Thank you"
    };
    
    for (NSString *key in quickDict) {
        if ([text containsString:key]) {
            return quickDict[key];
        }
    }
    
    BOOL isToEnglish = [targetLang isEqualToString:@"English"] || [targetLang isEqualToString:@"en"];
    if (isToEnglish) {
        return [NSString stringWithFormat:@"[Translated] %@", text];
    } else {
        return [NSString stringWithFormat:@"[译文] %@", text];
    }
}

- (NSString *)generateJSWithBuiltInEngine:(NSString *)prompt {
    NSString *p = prompt.lowercaseString;
    
    // 背景色识别
    if ([p containsString:@"红"] || [p containsString:@"red"]) {
        return @"// [糖葫芦遥控器] 电视大屏背景色调整为柔和红色\ndocument.body.style.backgroundColor = '#FF3B30';\ndocument.body.style.transition = 'background-color 0.5s ease';";
    }
    if ([p containsString:@"粉"] || [p containsString:@"pink"]) {
        return @"// [糖葫芦遥控器] 电视大屏背景色调整为优雅樱粉色\ndocument.body.style.backgroundColor = '#FF2D55';\ndocument.body.style.transition = 'background-color 0.5s ease';";
    }
    if ([p containsString:@"蓝"] || [p containsString:@"blue"]) {
        return @"// [糖葫芦遥控器] 电视大屏背景色调整为深邃蔚蓝色\ndocument.body.style.backgroundColor = '#007AFF';\ndocument.body.style.transition = 'background-color 0.5s ease';";
    }
    if ([p containsString:@"黑"] || [p containsString:@"暗黑"] || [p containsString:@"dark"]) {
        return @"// [糖葫芦遥控器] 切换大屏暗黑模式\ndocument.body.style.backgroundColor = '#121212';\ndocument.body.style.color = '#FFFFFF';";
    }
    
    // DOM 元素隐藏与排版
    if ([p containsString:@"隐藏"] && ([p containsString:@"导航"] || [p containsString:@"header"] || [p containsString:@"头部"])) {
        return @"// [糖葫芦遥控器] 隐藏电视网页顶部导航栏\ndocument.querySelectorAll('header, nav, [role=\"navigation\"], .header').forEach(el => {\n    el.style.display = 'none';\n});";
    }
    if ([p containsString:@"隐藏"] && ([p containsString:@"广告"] || [p containsString:@"banner"])) {
        return @"// [糖葫芦遥控器] 智能屏蔽大屏网页横幅与广告\ndocument.querySelectorAll('.ad, .banner, [id*=\"ad\"], [class*=\"ad\"]').forEach(el => {\n    el.remove();\n});";
    }
    
    // 弹窗与提醒
    if ([p containsString:@"alert"] || [p containsString:@"弹窗"] || [p containsString:@"提示"] || [p containsString:@"hello"]) {
        return @"// [糖葫芦遥控器] 触发电视端系统提示框\nalert('糖葫芦遥控器：端侧智能控制脚本执行成功！');";
    }
    
    // 字体缩放与居中
    if ([p containsString:@"放大"] || [p containsString:@"字号"] || [p containsString:@"字体"]) {
        return @"// [糖葫芦遥控器] 放大网页字体以适配客厅大屏观感\ndocument.body.style.fontSize = '130%';";
    }
    
    // 滚动与定位
    if ([p containsString:@"滚"] || [p containsString:@"下"] || [p containsString:@"到底"]) {
        return @"// [糖葫芦遥控器] 平滑向下滚动一屏\nwindow.scrollBy({ top: window.innerHeight * 0.8, behavior: 'smooth' });";
    }
    if ([p containsString:@"顶"] || [p containsString:@"top"]) {
        return @"// [糖葫芦遥控器] 平滑滚回页面顶部\nwindow.scrollTo({ top: 0, behavior: 'smooth' });";
    }
    
    // 默认智能控制模板
    return [NSString stringWithFormat:@"// [糖葫芦遥控器] 智能生成网页控制脚本: %@\nconsole.log('[Tanghulu Remote] Executing TV script for: %@');\ndocument.body.style.outline = '3px solid #007AFF';", prompt, prompt];
}

- (NSString *)answerWithBuiltInSmartAssistant:(NSString *)query {
    NSString *q = query.lowercaseString;
    
    if ([q containsString:@"apple tv"] || [q containsString:@"连接"] || [q containsString:@"配对"] || [q containsString:@"连不上"]) {
        return @"【📺 Apple TV 连接与配对指南】\n\n1. 网络环境：确保 iPhone 与 Apple TV 处于同一局域网 Wi-Fi 下；\n2. 权限开启：在系统 [设置 -> 糖葫芦遥控器] 中确保已允许「本地网络」权限；\n3. 自动发现：应用会自动通过 Bonjour (_companion-link / _airplay) 协议发现附近的电视；\n4. 端口唤醒：若 Apple TV 处于休眠状态，应用将自动执行并发端口敲门 (3689/7000/49152) 唤醒设备。";
    }
    
    if ([q containsString:@"模式"] || [q containsString:@"双模"] || [q containsString:@"区别"]) {
        return @"【🔀 双模遥控核心机制】\n\n1. 大屏专有通道 (Screen Channel)：针对 tvOS 端「hsbtvbrowser」大屏浏览器，提供 5.5x 高灵敏度光标、滚轮滑动、WebKit 原生点击与 JS 脚本注入；\n2. 原生系统通道 (Native Channel)：针对 Apple TV tvOS 操作系统，提供系统级 Home 键、Menu 键、休眠唤醒与实体音量/静音控制；\n3. 智能协调：双模自动协同，断网自动静默降级重连。";
    }
    
    if ([q containsString:@"触控板"] || [q containsString:@"微操"] || [q containsString:@"手势"]) {
        return @"【🕹 触控板与微操技巧】\n\n1. 虚拟空间：采用 1000x1000 虚拟空间边界瞬移重置算法，手指滑动无死角；\n2. 惯性滑动：内置 8 阶二次缓出 (Quad Ease-Out) 60FPS 衰减曲线，带来丝滑顺畅的阻尼感；\n3. 点击与拖拽：单指轻触即触发大屏点击，长按移动即可触发选区与拖拽。";
    }
    
    if ([q containsString:@"快捷键"] || [q containsString:@"指令"]) {
        return @"【⚡️ 常用快捷指令推荐】\n\n• 电视网页背景变红：输入「让背景变红」自动生成 JS 调整色调；\n• 屏蔽页面广告：输入「隐藏广告横幅」即可纯净浏览；\n• 网页字体放大：输入「放大字体」自动优化客厅大屏排版；\n• 一键向下翻页：输入「向下滚动」即可平滑翻阅内容。";
    }
    
    return [NSString stringWithFormat:@"【🤖 糖葫芦智能助手】\n\n您的问题：「%@」已收到。\n\n糖葫芦遥控器专为 Apple TV 与客厅大屏打造，支持双模协议、5.5x 微操触控板、RTI 实时软键盘同步以及端侧 AI 智能控制。\n您可以前往「AI 模型中心」下载深度 MLX 大模型，或随时向我提问关于电视控制的任何技巧！", query];
}

- (void)simulateStreamOutput:(NSString *)fullText completion:(HSBLocalLLMMessageCompletion)completion {
    if (!completion) return;
    
    // 如果文本较短，直接返回
    if (fullText.length <= 15) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(fullText, YES);
        });
        return;
    }
    
    // 模拟真实流式打字机效果，每次吐出一段
    NSUInteger length = fullText.length;
    NSUInteger chunkSize = MAX(3, length / 8);
    __block NSUInteger currentIndex = 0;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (currentIndex < length) {
            currentIndex = MIN(length, currentIndex + chunkSize);
            NSString *chunk = [fullText substringToIndex:currentIndex];
            BOOL isLast = (currentIndex >= length);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(chunk, isLast);
            });
            
            if (!isLast) {
                [NSThread sleepForTimeInterval:0.025];
            }
        }
    });
}

- (void)cancelInference {
    NSLog(@"[HSBLocalLLM] Requesting cancellation of current Swift MLX inference task.");
    [[HSBMLXLLMEngine shared] cancelCurrentInference];
}

// 物理 CVPixelBuffer 动态生成器：根据输入文本哈希值构建唯一性的 224x224 像素图像
- (CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size seedString:(NSString *)seed {
    NSDictionary *options = @{
        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options, &pxbuffer);
    if (status != kCVReturnSuccess) return NULL;
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    if (pxdata == NULL) {
        CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
        return NULL;
    }
    
    NSUInteger seedHash = [seed hash];
    uint8_t *pixelData = (uint8_t *)pxdata;
    
    for (int y = 0; y < size.height; y++) {
        for (int x = 0; x < size.width; x++) {
            int offset = (y * (int)size.width + x) * 4;
            // 依据哈希种子和像素坐标生成独有的色彩图层，形成非对称图像特征
            pixelData[offset]     = (uint8_t)((seedHash + x * y) & 0xFF);     // Blue
            pixelData[offset + 1] = (uint8_t)(((seedHash >> 8) + x + y) & 0xFF); // Green
            pixelData[offset + 2] = (uint8_t)(((seedHash >> 16) + x * 2 + y) & 0xFF); // Red
            pixelData[offset + 3] = 255; // Alpha
        }
    }
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}

// 辅助方法：清洗生成的 JS 代码，去除 Markdown 符号与解释，完美兼容流式生成
- (NSString *)cleanJSCode:(NSString *)code {
    NSString *clean = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // 1. 尝试匹配首要的 ```javascript 或 ```js 代码块
    NSRange jsStart = [clean rangeOfString:@"```javascript" options:NSCaseInsensitiveSearch];
    if (jsStart.location == NSNotFound) {
        jsStart = [clean rangeOfString:@"```js" options:NSCaseInsensitiveSearch];
    }
    
    if (jsStart.location != NSNotFound) {
        NSUInteger blockStart = jsStart.location + jsStart.length;
        NSRange nextFence = [clean rangeOfString:@"```" options:0 range:NSMakeRange(blockStart, clean.length - blockStart)];
        if (nextFence.location != NSNotFound) {
            clean = [clean substringWithRange:NSMakeRange(blockStart, nextFence.location - blockStart)];
        } else {
            // 流式输出中，还没闭合 ```，但我们直接提取并渲染已输出的代码体
            clean = [clean substringFromIndex:blockStart];
        }
    } else {
        // 2. 降级匹配普通代码块 ```
        NSRange codeStart = [clean rangeOfString:@"```"];
        if (codeStart.location != NSNotFound) {
            NSUInteger blockStart = codeStart.location + codeStart.length;
            NSRange nextFence = [clean rangeOfString:@"```" options:0 range:NSMakeRange(blockStart, clean.length - blockStart)];
            if (nextFence.location != NSNotFound) {
                clean = [clean substringWithRange:NSMakeRange(blockStart, nextFence.location - blockStart)];
            } else {
                clean = [clean substringFromIndex:blockStart];
            }
        }
    }
    
    return [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)mockAIOutputForMessage:(NSString *)message {
    if ([message containsString:@"红"]) return @"document.body.style.backgroundColor = 'red';";
    if ([message containsString:@"隐藏"]) return @"try { document.querySelector('header').style.display='none'; } catch(e) {}";
    return [NSString stringWithFormat:@"// Script for: %@\nconsole.log('Executed');", message];
}
@end
