#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HSBLocalLLMDownloadStatus) {
    HSBLocalLLMDownloadStatusNone,
    HSBLocalLLMDownloadStatusDownloading,
    HSBLocalLLMDownloadStatusPaused,
    HSBLocalLLMDownloadStatusFinished,
    HSBLocalLLMDownloadStatusFailed
};

/// 翻译引擎选择的 UserDefaults 键：YES = 使用苹果原生 Translation 框架，NO = 使用端侧大模型
static NSString * const HSBTranslationUseAppleKey = @"HSBTranslationUseAppleFramework";

@interface HSBLocalLLMModel : NSObject

@property (nonatomic, copy) NSString *modelId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *modelDescription;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) HSBLocalLLMDownloadStatus status;
@property (nonatomic, assign) double downloadProgress;

/// 是否激活为翻译/通用模型（当 useAppleTranslation=NO 时，翻译+JS 共用此模型）
@property (nonatomic, assign) BOOL isActive;

/// 是否激活为 JS 生成专用模型（仅当 useAppleTranslation=YES 时生效）
@property (nonatomic, assign) BOOL isJSActive;

@property (nonatomic, strong, nullable) NSData *resumeData;

- (instancetype)initWithId:(NSString *)modelId name:(NSString *)name description:(NSString *)description url:(NSURL *)url;

@end

typedef void (^HSBLocalLLMProgressBlock)(double progress);
typedef void (^HSBLocalLLMCompletionBlock)(BOOL success, NSError * _Nullable error);
typedef void (^HSBLocalLLMMessageCompletion)(NSString *response, BOOL isFinished);

@interface HSBLocalLLMManager : NSObject

@property (nonatomic, strong, readonly) NSArray<HSBLocalLLMModel *> *availableModels;

/// 翻译/通用 LLM 激活模型（useAppleTranslation=NO 时 JS 也用此模型）
@property (nonatomic, strong, nullable) HSBLocalLLMModel *activeModel;

/// JS 生成专用激活模型（仅当 useAppleTranslation=YES 时有效）
@property (nonatomic, strong, nullable) HSBLocalLLMModel *jsActiveModel;

+ (instancetype)shared;
+ (NSString *)translationSystemPrompt;

/// 当前是否使用苹果原生 Translation 框架进行翻译
+ (BOOL)useAppleTranslation;
+ (void)setUseAppleTranslation:(BOOL)use;

- (void)downloadModel:(HSBLocalLLMModel *)model progress:(HSBLocalLLMProgressBlock)progress completion:(HSBLocalLLMCompletionBlock)completion;
- (void)pauseDownloadModel:(HSBLocalLLMModel *)model;

/// 激活为翻译/通用模型（useAppleTranslation=NO 时也承担 JS 生成）
- (void)activateModel:(HSBLocalLLMModel *)model;
- (void)deactivateModel:(HSBLocalLLMModel *)model;

/// 激活/取消为 JS 生成专用模型（仅在 useAppleTranslation=YES 时需调用）
- (void)activateJSModel:(HSBLocalLLMModel *)model;
- (void)deactivateJSModel:(HSBLocalLLMModel *)model;

/// 旧接口兼容
- (void)processMessage:(NSString *)message systemPrompt:(NSString *)systemPrompt completion:(HSBLocalLLMMessageCompletion)completion;

/// 带任务类型的新接口：type=1 翻译，type=2 JS 生成。内部自动选择正确激活模型
- (void)processMessage:(NSString *)message systemPrompt:(NSString *)systemPrompt type:(NSInteger)type completion:(HSBLocalLLMMessageCompletion)completion;

- (void)cancelInference;

/// 动态添加用户自定义的端侧大模型（指定自定义名称与 HuggingFace Repo ID）
- (BOOL)addCustomModelWithName:(NSString *)name repoId:(NSString *)repoId error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
