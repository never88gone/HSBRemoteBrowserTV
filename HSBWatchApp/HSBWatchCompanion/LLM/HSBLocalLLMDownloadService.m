#import "HSBLocalLLMDownloadService.h"
#import "HSBWatchCompanion-Swift.h"

@implementation HSBLocalLLMDownloadService

+ (instancetype)sharedService {
    static HSBLocalLLMDownloadService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HSBLocalLLMDownloadService alloc] init];
    });
    return instance;
}

- (void)downloadModel:(HSBLocalLLMModel *)model
             progress:(nullable HSBLocalLLMProgressBlock)progress
           completion:(nullable HSBLocalLLMCompletionBlock)completion {
    if (model.status == HSBLocalLLMDownloadStatusDownloading) return;
    
    model.status = HSBLocalLLMDownloadStatusDownloading;
    
    NSString *customHost = model.url ? model.url.absoluteString : nil;
    [[HSBMLXLLMEngine shared] loadAndActivateModelWithModelId:model.modelId customHost:customHost callback:^(NSString * _Nonnull logText, double fractionCompleted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (fractionCompleted < 0) {
                model.status = HSBLocalLLMDownloadStatusFailed;
                model.downloadProgress = 0.0;
                
                NSError *error = [NSError errorWithDomain:@"com.hsb.llm" code:-1 userInfo:@{
                    NSLocalizedDescriptionKey: logText.length > 0 ? logText : @"大模型权重拉取或校验失败，请检查网络连接或切换镜像源后重试。"
                }];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFailedNotification" object:model userInfo:@{@"error": error}];
                if (completion) completion(NO, error);
                return;
            }
            
            model.downloadProgress = fractionCompleted;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadProgressNotification" object:model];
            if (progress) progress(fractionCompleted);
            
            if (fractionCompleted >= 1.0) {
                model.status = HSBLocalLLMDownloadStatusFinished;
                
                NSString *cacheKey = [NSString stringWithFormat:@"HSBLocalLLM_Downloaded_%@", model.modelId];
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:cacheKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
                if (completion) completion(YES, nil);
            }
        });
    }];
}

- (BOOL)deleteModelCacheForModel:(HSBLocalLLMModel *)model {
    if (!model) return NO;
    
    BOOL deleted = [[HSBMLXLLMEngine shared] deleteModelCacheWithModelId:model.modelId];
    
    NSString *cacheKey = [NSString stringWithFormat:@"HSBLocalLLM_Downloaded_%@", model.modelId];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:cacheKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    model.status = HSBLocalLLMDownloadStatusNone;
    model.downloadProgress = 0.0;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBLocalLLMDownloadFinishedNotification" object:model];
    return deleted;
}

- (long long)getFreeDiskSpace {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [[attrs objectForKey:NSFileSystemFreeSize] longLongValue];
}

@end
