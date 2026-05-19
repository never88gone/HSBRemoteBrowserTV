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
    NSString *source = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationSourceLanguage"] ?: @"Auto";
    NSString *target = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
    
    NSDictionary *langMap = @{
        @"Auto": @"Auto Detect",
        @"Chinese": @"Chinese",
        @"English": @"English",
        @"Japanese": @"Japanese",
        @"Korean": @"Korean",
        @"French": @"French",
        @"German": @"German",
        @"Spanish": @"Spanish",
        @"Russian": @"Russian"
    };
    
    NSString *sourceEng = langMap[source] ?: @"Auto Detect";
    NSString *targetEng = langMap[target] ?: @"Chinese";
    
    if ([source isEqualToString:@"Auto"]) {
        if ([target isEqualToString:@"Chinese"]) {
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

- (void)setupDefaultModels {
    NSMutableArray *allModels = [NSMutableArray array];
    
    // 加载用户添加 of 自定义模型列表
    NSArray *customList = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSBLocalLLM_CustomModelsList"];
    for (NSDictionary *dict in customList) {
        NSString *mId = dict[@"modelId"];
        NSString *name = dict[@"name"];
        NSString *desc = dict[@"description"];
        NSString *originalUrl = dict[@"url"];
        if (mId && name) {
            NSURL *dummyUrl = nil;
            if (originalUrl && originalUrl.length > 0) {
                dummyUrl = [NSURL URLWithString:originalUrl];
            } else {
                dummyUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://hf-mirror.com/%@/resolve/main/tokenizer.json", mId]];
            }
            [allModels addObject:[[HSBLocalLLMModel alloc] initWithId:mId name:name description:desc url:dummyUrl]];
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
    // type=1: 翻译, type=2: JS生成, type=0: 通用
    BOOL useApple = [HSBLocalLLMManager useAppleTranslation];
    
    if (type == 1 && useApple) {
        NSString *sourceLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationSourceLanguage"] ?: @"Auto";
        NSString *targetLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
        
        NSLog(@"[HSBLocalLLM] 🔵 使用 Apple 原生翻译框架执行翻译。源语言: %@, 目标语言: %@", sourceLang, targetLang);
        
        NSArray *components = [message componentsSeparatedByString:@"\n"];
        NSString *rawText = components.count > 0 ? components.lastObject : message;
        
        [HSBAppleTranslationHelper translateWithText:rawText sourceLanguage:sourceLang targetLanguage:targetLang completion:^(NSString * _Nullable translatedText, NSError * _Nullable error) {
            if (error) {
                NSLog(@"[HSBLocalLLM] Apple Translation 错误: %@. 正在自动降级至本地通用大模型...", error.localizedDescription);
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
                    
                    NSLog(@"[HSBLocalLLM] ⚠️ 已自动降级！正在使用本地通用大模型进行翻译: %@ (%@)", self.activeModel.name, self.activeModel.modelId);
                    
                    [[HSBMLXLLMEngine shared] generateWithMLXWithSystemPrompt:fallbackSystemPrompt userPrompt:fallbackUserPrompt modelId:self.activeModel.modelId callback:^(NSString * _Nonnull partialResponse, BOOL isFinished) {
                        if (completion) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(partialResponse, isFinished);
                            });
                        }
                    }];
                } else {
                    if (completion) {
                        completion([NSString stringWithFormat:@"❌ 翻译失败: Apple 翻译不可用且本地模型未激活。\n(错误信息: %@)", error.localizedDescription], YES);
                    }
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
        // 使用苹果翻译框架时，JS 生成走独立的 jsActiveModel
        targetModel = self.jsActiveModel;
        if (!targetModel) {
            if (completion) completion(@"⚠️ JS 生成模型未配置，请前往 [AI 模型中心 → JS 生成模型] 激活一个专用模型。", YES);
            return;
        }
        NSLog(@"[HSBLocalLLM] 🟣 使用本地大模型执行 JS 代码生成。正在使用专用大模型: %@ (%@)", targetModel.name, targetModel.modelId);
    } else {
        // 翻译+JS 共用同一个 activeModel
        targetModel = self.activeModel;
        if (!targetModel) {
            if (completion) completion(@"端侧模型未激活，请先下载并激活大模型！", YES);
            return;
        }
        if (type == 1) {
            NSLog(@"[HSBLocalLLM] 🟢 使用本地大模型执行翻译任务。正在使用大模型: %@ (%@)", targetModel.name, targetModel.modelId);
        } else if (type == 2) {
            NSLog(@"[HSBLocalLLM] 🟣 使用本地大模型执行 JS 代码生成。正在使用大模型: %@ (%@)", targetModel.name, targetModel.modelId);
        } else {
            NSLog(@"[HSBLocalLLM] 🟡 使用本地大模型执行通用对话。正在使用大模型: %@ (%@)", targetModel.name, targetModel.modelId);
        }
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
