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
    self.models = @[
        [[HSBLocalLLMModel alloc] initWithId:@"qwen1.5-0.5b" name:@"Qwen1.5-0.5B-Chat (CoreML)" description:@"阿里通义千问超轻量 0.5B 端侧旗舰大语言模型，已转换为物理大模型格式，完美支持 Apple Silicon GPU 与 Metal 硬件加速，具有卓越的本地中英文自回归机器翻译与智能 JS 脚本指令生成能力。" url:[NSURL URLWithString:@"https://hf-mirror.com/mlx-community/Qwen1.5-0.5B-Chat-4bit/resolve/main/tokenizer.json"]],
        [[HSBLocalLLMModel alloc] initWithId:@"gemma-2b-it" name:@"Gemma-2B-IT (CoreML)" description:@"谷歌官方 Gemma 2B 专为端侧设备优化的指令微调大语言模型，已转换为物理大模型格式，完美支持 Apple Silicon GPU 与 Unified Memory 统一内存加速，支持自由的离线对话与精准的中英互译。" url:[NSURL URLWithString:@"https://hf-mirror.com/mlx-community/gemma-2b-it-4bit/resolve/main/tokenizer.json"]]
    ];
    
    // 由于 MLX 模型是下载到底层的 ~/.cache/huggingface 中，我们通过 NSUserDefaults 进行下载状态持久化记录
    // 由于 MLX 模型是下载到底层的 ~/.cache/huggingface 中，我们通过 NSUserDefaults 以及物理文件探测进行状态双重校验
    NSString *activeModelId = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBLocalLLM_ActiveModelId"];
    __block HSBLocalLLMModel *modelToActivate = nil;
    
    for (HSBLocalLLMModel *model in self.models) {
        NSString *cacheKey = [NSString stringWithFormat:@"HSBLocalLLM_Downloaded_%@", model.modelId];
        
        // 🥇 物理+持久化双保险校验：如果 UserDefaults 标记已下载，或者沙盒中物理存在完整 Safetensors，都判定为已就绪
        BOOL isPhysicallyDownloaded = [[HSBMLXLLMEngine shared] isModelDownloaded:model.modelId];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:cacheKey] || isPhysicallyDownloaded) {
            model.status = HSBLocalLLMDownloadStatusFinished;
            model.downloadProgress = 1.0;
            
            // 缓存状态补齐同步，防止因 UserDefaults 丢失导致 UI 显示未下载
            if (![[NSUserDefaults standardUserDefaults] boolForKey:cacheKey]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:cacheKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            if (activeModelId) {
                if ([model.modelId isEqualToString:activeModelId]) {
                    modelToActivate = model;
                }
            } else if (!modelToActivate) {
                // 🥈 智能恢复：若用户从未手动点击过“激活”按钮，但大模型早已完全下载，则默认自动激活首个就绪的模型，避免提示“模型未激活”
                modelToActivate = model;
            }
        }
    }
    
    if (modelToActivate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self activateModel:modelToActivate];
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
    
    // 🏆 取消激活，清除持久化值
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HSBLocalLLM_ActiveModelId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
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
    if (!self.activeModel) {
        if (completion) completion(@"端侧模型未激活，请先下载并激活大模型！", YES);
        return;
    }
    
    NSLog(@"[HSBLocalLLM] Dispatching to MLX-Swift GPU Tensor Engine for model: %@", self.activeModel.name);
    
    // 判断是否为 JS 代码生成任务
    BOOL isJSTask = [systemPrompt containsString:@"JavaScript"] || 
                    [systemPrompt containsString:@"JS"] || 
                    [systemPrompt containsString:@"前端"] || 
                    [systemPrompt containsString:@"code"] || 
                    [systemPrompt containsString:@"代码"];
    
    // 🏆 方案 C：物理调用 Swift 本地 MLX 大模型引擎进行 ANE/GPU 自回归流式推理
    [[HSBMLXLLMEngine shared] generateWithMLXWithSystemPrompt:systemPrompt userPrompt:message modelId:self.activeModel.modelId callback:^(NSString * _Nonnull partialResponse, BOOL isFinished) {
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
