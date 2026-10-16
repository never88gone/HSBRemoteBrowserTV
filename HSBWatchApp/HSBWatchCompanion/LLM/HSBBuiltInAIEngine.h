#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HSBBuiltInAIStreamCompletion)(NSString *response, BOOL isFinished);

@interface HSBBuiltInAIEngine : NSObject

+ (instancetype)sharedEngine;

- (void)processMessage:(NSString *)message
          systemPrompt:(nullable NSString *)systemPrompt
                  type:(NSInteger)type
            completion:(HSBBuiltInAIStreamCompletion)completion;

- (NSString *)translateText:(NSString *)text targetLang:(NSString *)targetLang;
- (NSString *)generateJSWithPrompt:(NSString *)prompt;
- (NSString *)answerQuery:(NSString *)query;

- (NSString *)cleanJSCode:(NSString *)code;
- (void)simulateStreamOutput:(NSString *)fullText completion:(HSBBuiltInAIStreamCompletion)completion;

@end

NS_ASSUME_NONNULL_END
