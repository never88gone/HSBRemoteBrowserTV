#import <Foundation/Foundation.h>
#import "HSBLocalLLMManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface HSBLocalLLMDownloadService : NSObject

+ (instancetype)sharedService;

- (void)downloadModel:(HSBLocalLLMModel *)model
             progress:(nullable HSBLocalLLMProgressBlock)progress
           completion:(nullable HSBLocalLLMCompletionBlock)completion;

- (BOOL)deleteModelCacheForModel:(HSBLocalLLMModel *)model;
- (long long)getFreeDiskSpace;

@end

NS_ASSUME_NONNULL_END
