#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HSBCustomAPIMessageCompletion)(NSString *response, BOOL isFinished);

@interface HSBCustomLLMAPIService : NSObject

+ (instancetype)sharedService;

+ (BOOL)useCustomAPI;
+ (void)setUseCustomAPI:(BOOL)use;

+ (NSString *)customAPIEndpoint;
+ (void)setCustomAPIEndpoint:(NSString *)endpoint;

+ (NSString *)customAPIKey;
+ (void)setCustomAPIKey:(NSString *)key;

+ (NSString *)customAPIModel;
+ (void)setCustomAPIModel:(NSString *)model;

- (void)processMessage:(NSString *)message
          systemPrompt:(nullable NSString *)systemPrompt
                  type:(NSInteger)type
            completion:(HSBCustomAPIMessageCompletion)completion
       fallbackHandler:(void (^)(void))fallback;

@end

NS_ASSUME_NONNULL_END
