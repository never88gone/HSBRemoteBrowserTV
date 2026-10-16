//
//  HSBLLMVerificationTest.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBLLMVerificationTest : NSObject

/// 运行全套大模型下载、状态机、缓存清理、调用推理与降级验证测试
+ (void)runAllLLMVerificationsWithCompletion:(void (^)(BOOL allPassed, NSString *report))completion;

@end

NS_ASSUME_NONNULL_END
