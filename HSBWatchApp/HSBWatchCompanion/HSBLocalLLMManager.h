#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HSBLocalLLMDownloadStatus) {
    HSBLocalLLMDownloadStatusNone,
    HSBLocalLLMDownloadStatusDownloading,
    HSBLocalLLMDownloadStatusPaused,
    HSBLocalLLMDownloadStatusFinished,
    HSBLocalLLMDownloadStatusFailed
};

@interface HSBLocalLLMModel : NSObject

@property (nonatomic, copy) NSString *modelId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *modelDescription;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) HSBLocalLLMDownloadStatus status;
@property (nonatomic, assign) double downloadProgress;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, strong, nullable) NSData *resumeData;

- (instancetype)initWithId:(NSString *)modelId name:(NSString *)name description:(NSString *)description url:(NSURL *)url;

@end

typedef void (^HSBLocalLLMProgressBlock)(double progress);
typedef void (^HSBLocalLLMCompletionBlock)(BOOL success, NSError * _Nullable error);
typedef void (^HSBLocalLLMMessageCompletion)(NSString *response, BOOL isFinished);

@interface HSBLocalLLMManager : NSObject

@property (nonatomic, strong, readonly) NSArray<HSBLocalLLMModel *> *availableModels;
@property (nonatomic, strong, nullable) HSBLocalLLMModel *activeModel;

+ (instancetype)shared;
+ (NSString *)translationSystemPrompt;

- (void)downloadModel:(HSBLocalLLMModel *)model progress:(HSBLocalLLMProgressBlock)progress completion:(HSBLocalLLMCompletionBlock)completion;
- (void)pauseDownloadModel:(HSBLocalLLMModel *)model;
- (void)activateModel:(HSBLocalLLMModel *)model;
- (void)deactivateModel:(HSBLocalLLMModel *)model;
- (void)processMessage:(NSString *)message systemPrompt:(NSString *)systemPrompt completion:(HSBLocalLLMMessageCompletion)completion;
- (void)cancelInference;

@end

NS_ASSUME_NONNULL_END
