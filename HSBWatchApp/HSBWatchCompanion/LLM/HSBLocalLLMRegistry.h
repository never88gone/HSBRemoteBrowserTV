//
//  HSBLocalLLMRegistry.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>
#import "HSBLocalLLMManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface HSBLocalLLMRegistry : NSObject

+ (NSArray<HSBLocalLLMModel *> *)loadConfiguredModels;
+ (BOOL)registerCustomModelWithName:(NSString *)name repoId:(NSString *)repoId error:(NSError **)error;
+ (BOOL)removeCustomModelWithId:(NSString *)modelId;

@end

NS_ASSUME_NONNULL_END
