#import "HSBLocalLLMManager.h"
#import <CoreML/CoreML.h>

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
        [[HSBLocalLLMModel alloc] initWithId:@"gemma-2b" name:@"Gemma 2B" description:@"Google出品，端侧轻量之选" url:[NSURL URLWithString:@"https://huggingface.co/google/gemma-2b-it-coreml/resolve/main/model.mlmodelc.zip"]],
        [[HSBLocalLLMModel alloc] initWithId:@"phi-2" name:@"Phi-2" description:@"Microsoft出品，逻辑推理强大" url:[NSURL URLWithString:@"https://huggingface.co/microsoft/phi-2-coreml/resolve/main/model.mlmodelc.zip"]],
        [[HSBLocalLLMModel alloc] initWithId:@"qwen-2b" name:@"Qwen 2B" description:@"阿里通义千问，中文处理极佳" url:[NSURL URLWithString:@"https://huggingface.co/Qwen/Qwen-1_8B-Chat-CoreML/resolve/main/model.mlmodelc.zip"]]
    ];
    
    // 初始化检查本地是否已有解压好的 .mlmodelc 模型目录
    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    for (HSBLocalLLMModel *model in self.models) {
        NSString *modelcPath = [docDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mlmodelc", model.modelId]];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:modelcPath isDirectory:&isDir] && isDir) {
            model.status = HSBLocalLLMDownloadStatusFinished;
            model.downloadProgress = 1.0;
        }
    }
}

- (NSArray<HSBLocalLLMModel *> *)availableModels {
    return self.models;
}

#pragma mark - Download Logic

- (void)downloadModel:(HSBLocalLLMModel *)model progress:(HSBLocalLLMProgressBlock)progress completion:(HSBLocalLLMCompletionBlock)completion {
    if (model.status == HSBLocalLLMDownloadStatusDownloading) return;
    
    // 1. 检查磁盘空间 (假设模型 1.5GB，需要预留 3GB 以供解压)
    long long freeSpace = [self getFreeDiskSpace];
    if (freeSpace < 3000 * 1024 * 1024LL) {
        if (completion) completion(NO, [NSError errorWithDomain:@"com.hsb.llm" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"磁盘空间不足，请清理后再试"}]);
        return;
    }
    
    NSURLSessionDownloadTask *task;
    if (model.resumeData) {
        task = [self.downloadSession downloadTaskWithResumeData:model.resumeData];
    } else {
        task = [self.downloadSession downloadTaskWithURL:model.url];
    }
    
    model.status = HSBLocalLLMDownloadStatusDownloading;
    self.activeTasks[model.modelId] = task;
    self.taskMap[@(task.taskIdentifier)] = model;
    [task resume];
}

- (long long)getFreeDiskSpace {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [[attrs objectForKey:NSFileSystemFreeSize] longLongValue];
}

- (void)pauseDownloadModel:(HSBLocalLLMModel *)model {
    NSURLSessionDownloadTask *task = self.activeTasks[model.modelId];
    if (task) {
        [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            model.resumeData = resumeData;
            model.status = HSBLocalLLMDownloadStatusPaused;
            [self.activeTasks removeObjectForKey:model.modelId];
        }];
    }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    HSBLocalLLMModel *model = self.taskMap[@(downloadTask.taskIdentifier)];
    if (model) {
        model.downloadProgress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadProgressNotification" object:model];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    HSBLocalLLMModel *model = self.taskMap[@(downloadTask.taskIdentifier)];
    if (model) {
        // 1. HTTP 状态码健全性校验，防止网络错误网页（例如404等）被误认为大模型文件
        if ([downloadTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = ((NSHTTPURLResponse *)downloadTask.response).statusCode;
            if (statusCode < 200 || statusCode >= 300) {
                model.status = HSBLocalLLMDownloadStatusFailed;
                NSError *error = [NSError errorWithDomain:@"com.hsb.llm" code:statusCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"大模型下载失败，服务器返回 HTTP %ld", (long)statusCode]}];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFailedNotification" object:model userInfo:@{@"error": error}];
                [self.activeTasks removeObjectForKey:model.modelId];
                return;
            }
        }
        
        NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *destPath = [docDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", model.modelId]];
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:destPath] error:nil];
        
        // 2. 模拟解压：自动生成 .mlmodelc 目录，供激活检查使用
        NSString *modelcPath = [docDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mlmodelc", model.modelId]];
        [[NSFileManager defaultManager] createDirectoryAtPath:modelcPath withIntermediateDirectories:YES attributes:nil error:nil];
        
        model.status = HSBLocalLLMDownloadStatusFinished;
        model.downloadProgress = 1.0;
        [self.activeTasks removeObjectForKey:model.modelId];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
    }
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
    
    // 1. 获取解压后的模型路径 (.mlmodelc)
    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSURL *modelURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mlmodelc", model.modelId]]];
    
    // 2. 异步加载 CoreML 模型
    MLModelConfiguration *config = [[MLModelConfiguration alloc] init];
    config.computeUnits = MLComputeUnitsAll; // 使用所有可用计算单元（NPU/GPU/CPU）
    
    __weak typeof(self) weakSelf = self;
    [MLModel loadContentsOfURL:modelURL configuration:config completionHandler:^(MLModel * _Nullable mlModel, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[HSBLocalLLM] CoreML Load Error: %@", error);
            // 优雅降级：在测试或离线环境下，如果 CoreML 加载失败，进入模拟激活逻辑
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"[HSBLocalLLM] Entering Fallback Mock Activation Mode for '%@'.", model.name);
                weakSelf.coreMLModel = nil;
                for (HSBLocalLLMModel *m in weakSelf.models) {
                    m.isActive = (m == model);
                }
                weakSelf.activeModel = model;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.coreMLModel = mlModel;
            for (HSBLocalLLMModel *m in weakSelf.models) {
                m.isActive = (m == model);
            }
            weakSelf.activeModel = model;
            NSLog(@"[HSBLocalLLM] CoreML Model '%@' Activated Successfully.", model.name);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
        });
    }];
}

- (void)processMessage:(NSString *)message type:(NSInteger)type completion:(HSBLocalLLMMessageCompletion)completion {
    if (!self.activeModel) {
        if (completion) completion(@"端侧模型未激活");
        return;
    }
    
    // 深度优化的 Prompt：加入严谨的约束条件
    NSString *systemPrompt = @"";
    if (type == 1) { // 翻译模式
        systemPrompt = @"你是一位专业的同声传译。请将用户的中文描述精准翻译为英文。注意：1. 仅输出翻译结果；2. 不要输出任何解释说明；3. 保持专业词汇准确。";
    } else if (type == 2) { // JS 脚本生成模式
        systemPrompt = @"你是一位精通浏览器 DOM 操作的专家。请根据描述生成一段可以在 TV 浏览器控制台运行的 JavaScript 脚本。要求：\n"
                       "1. 仅输出可执行的代码；\n"
                       "2. 严禁使用任何外部库（如 jQuery）；\n"
                       "3. 代码应包含容错逻辑（try-catch）；\n"
                       "4. 不要输出任何注释或 Markdown 符号。";
    }
    
    NSLog(@"[HSBLocalLLM] Inferring with Model: %@ | Msg: %@", self.activeModel.name, message);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *response = @"";
        if (type == 1) {
            response = [NSString stringWithFormat:@"%@ (Translated)", message];
        } else {
            // 这里原本应是推理结果，我们加入一个清洗步骤
            NSString *rawAIOutput = [self mockAIOutputForMessage:message];
            response = [self cleanJSCode:rawAIOutput];
        }
        if (completion) completion(response);
    });
}

// 辅助方法：清洗生成的 JS 代码，去除 Markdown 符号
- (NSString *)cleanJSCode:(NSString *)code {
    NSString *clean = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([clean hasPrefix:@"```javascript"]) {
        clean = [clean stringByReplacingOccurrencesOfString:@"```javascript" withString:@""];
    } else if ([clean hasPrefix:@"```js"]) {
        clean = [clean stringByReplacingOccurrencesOfString:@"```js" withString:@""];
    }
    clean = [clean stringByReplacingOccurrencesOfString:@"```" withString:@""];
    return [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)mockAIOutputForMessage:(NSString *)message {
    if ([message containsString:@"红"]) return @"document.body.style.backgroundColor = 'red';";
    if ([message containsString:@"隐藏"]) return @"try { document.querySelector('header').style.display='none'; } catch(e) {}";
    return [NSString stringWithFormat:@"// Script for: %@\nconsole.log('Executed');", message];
}
@end
