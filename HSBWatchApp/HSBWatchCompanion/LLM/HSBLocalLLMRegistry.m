//
//  HSBLocalLLMRegistry.m
//  HSBWatchCompanion
//

#import "HSBLocalLLMRegistry.h"

static NSString * const kCustomModelsListKey = @"HSBLocalLLM_CustomModelsList";

@implementation HSBLocalLLMRegistry

+ (NSArray<HSBLocalLLMModel *> *)loadConfiguredModels {
    NSMutableArray<HSBLocalLLMModel *> *allModels = [NSMutableArray array];
    
    NSArray *builtInConfigs = @[
        @{
            @"id": @"mlx-community/Qwen1.5-0.5B-Chat-4bit",
            @"name": @"Qwen1.5-0.5B (官方推荐)",
            @"desc": @"轻量多语言通识模型，支持中英文同声传译与日常对话，耗费内存极低 (约 350MB)。",
            @"url": @"https://hf-mirror.com/mlx-community/Qwen1.5-0.5B-Chat-4bit/resolve/main/tokenizer.json"
        },
        @{
            @"id": @"mlx-community/SmolLM-135M-Instruct-4bit",
            @"name": @"SmolLM-135M (极速体验)",
            @"desc": @"超轻量极致模型，下载极快，硬件内存占用低 (约 90MB)，适合低功耗场景快速体验。",
            @"url": @"https://hf-mirror.com/mlx-community/SmolLM-135M-Instruct-4bit/resolve/main/tokenizer.json"
        },
        @{
            @"id": @"mlx-community/gemma-2-2b-it-4bit",
            @"name": @"Gemma-2-2B-IT (深度推理)",
            @"desc": @"Google 深度指令遵循模型，适合前端网页复杂 JS 控制脚本生成 (约 1.2GB)。",
            @"url": @"https://hf-mirror.com/mlx-community/gemma-2-2b-it-4bit/resolve/main/tokenizer.json"
        }
    ];
    
    for (NSDictionary *info in builtInConfigs) {
        [allModels addObject:[[HSBLocalLLMModel alloc] initWithId:info[@"id"]
                                                            name:info[@"name"]
                                                     description:info[@"desc"]
                                                             url:[NSURL URLWithString:info[@"url"]]]];
    }
    
    NSArray *customList = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomModelsListKey];
    for (NSDictionary *dict in customList) {
        NSString *mId = dict[@"modelId"];
        NSString *name = dict[@"name"];
        NSString *desc = dict[@"description"];
        NSString *originalUrl = dict[@"url"];
        if (mId && name) {
            BOOL alreadyExists = NO;
            for (HSBLocalLLMModel *existing in allModels) {
                if ([existing.modelId.lowercaseString isEqualToString:mId.lowercaseString]) {
                    alreadyExists = YES;
                    break;
                }
            }
            if (!alreadyExists) {
                NSURL *dummyUrl = (originalUrl && originalUrl.length > 0) ? [NSURL URLWithString:originalUrl] : [NSURL URLWithString:[NSString stringWithFormat:@"https://hf-mirror.com/%@/resolve/main/tokenizer.json", mId]];
                [allModels addObject:[[HSBLocalLLMModel alloc] initWithId:mId name:name description:desc url:dummyUrl]];
            }
        }
    }
    return [allModels copy];
}

+ (BOOL)registerCustomModelWithName:(NSString *)name repoId:(NSString *)repoId error:(NSError **)error {
    NSString *cleanName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *cleanRepo = [repoId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (cleanName.length == 0 || cleanRepo.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"HSBLocalLLMRegistry"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"模型名称和 HuggingFace Repo ID 不能为空"}];
        }
        return NO;
    }
    
    NSArray *parts = [cleanRepo componentsSeparatedByString:@"/"];
    if (parts.count != 2) {
        if (error) {
            *error = [NSError errorWithDomain:@"HSBLocalLLMRegistry"
                                         code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Repo ID 格式必须为 '组织名/模型名'，例如 'mlx-community/Qwen2.5-0.5B-Instruct-4bit'"}];
        }
        return NO;
    }
    
    NSArray<HSBLocalLLMModel *> *current = [self loadConfiguredModels];
    for (HSBLocalLLMModel *m in current) {
        if ([m.modelId.lowercaseString isEqualToString:cleanRepo.lowercaseString]) {
            if (error) {
                *error = [NSError errorWithDomain:@"HSBLocalLLMRegistry"
                                             code:-3
                                         userInfo:@{NSLocalizedDescriptionKey: @"该模型已经存在于列表中"}];
            }
            return NO;
        }
    }
    
    NSURL *downloadUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://hf-mirror.com/%@/resolve/main/tokenizer.json", cleanRepo]];
    NSDictionary *newCustom = @{
        @"modelId": cleanRepo,
        @"name": cleanName,
        @"description": [NSString stringWithFormat:@"自定义引入的开源端侧权重 (%@)", cleanRepo],
        @"url": downloadUrl.absoluteString
    };
    
    NSMutableArray *saved = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:kCustomModelsListKey] ?: @[]];
    [saved addObject:newCustom];
    [[NSUserDefaults standardUserDefaults] setObject:saved forKey:kCustomModelsListKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return YES;
}

+ (BOOL)removeCustomModelWithId:(NSString *)modelId {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomModelsListKey];
    if (!saved) return NO;
    
    NSMutableArray *updated = [NSMutableArray array];
    for (NSDictionary *dict in saved) {
        if (![dict[@"modelId"] isEqualToString:modelId]) {
            [updated addObject:dict];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:updated forKey:kCustomModelsListKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return YES;
}

@end
