#import "HSBCustomLLMAPIService.h"
#import "HSBBuiltInAIEngine.h"

static NSString * const HSBLocalLLMUseCustomAPIKey = @"HSBLocalLLM_UseCustomAPI";
static NSString * const HSBLocalLLMCustomAPIEndpointKey = @"HSBLocalLLM_CustomAPIEndpoint";
static NSString * const HSBLocalLLMCustomAPIKeyKey = @"HSBLocalLLM_CustomAPIKey";
static NSString * const HSBLocalLLMCustomAPIModelKey = @"HSBLocalLLM_CustomAPIModel";

@implementation HSBCustomLLMAPIService

+ (instancetype)sharedService {
    static HSBCustomLLMAPIService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HSBCustomLLMAPIService alloc] init];
    });
    return instance;
}

+ (BOOL)useCustomAPI {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HSBLocalLLMUseCustomAPIKey];
}

+ (void)setUseCustomAPI:(BOOL)use {
    [[NSUserDefaults standardUserDefaults] setBool:use forKey:HSBLocalLLMUseCustomAPIKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)customAPIEndpoint {
    NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:HSBLocalLLMCustomAPIEndpointKey];
    if (!val || val.length == 0) {
        return @"http://localhost:11434/v1";
    }
    return val;
}

+ (void)setCustomAPIEndpoint:(NSString *)endpoint {
    [[NSUserDefaults standardUserDefaults] setObject:endpoint forKey:HSBLocalLLMCustomAPIEndpointKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)customAPIKey {
    return [[NSUserDefaults standardUserDefaults] stringForKey:HSBLocalLLMCustomAPIKeyKey] ?: @"";
}

+ (void)setCustomAPIKey:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:key forKey:HSBLocalLLMCustomAPIKeyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)customAPIModel {
    NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:HSBLocalLLMCustomAPIModelKey];
    if (!val || val.length == 0) {
        return @"deepseek-chat";
    }
    return val;
}

+ (void)setCustomAPIModel:(NSString *)model {
    [[NSUserDefaults standardUserDefaults] setObject:model forKey:HSBLocalLLMCustomAPIModelKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)processMessage:(NSString *)message
          systemPrompt:(nullable NSString *)systemPrompt
                  type:(NSInteger)type
            completion:(HSBCustomAPIMessageCompletion)completion
       fallbackHandler:(void (^)(void))fallback {
    if (!completion) return;
    
    NSString *rawEndpoint = [HSBCustomLLMAPIService customAPIEndpoint];
    NSString *apiKey = [HSBCustomLLMAPIService customAPIKey];
    NSString *modelName = [HSBCustomLLMAPIService customAPIModel];
    
    NSString *urlString = rawEndpoint;
    if (![urlString hasSuffix:@"/chat/completions"]) {
        if ([urlString hasSuffix:@"/"]) {
            urlString = [urlString stringByAppendingString:@"chat/completions"];
        } else {
            urlString = [urlString stringByAppendingString:@"/chat/completions"];
        }
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        [[HSBBuiltInAIEngine sharedEngine] simulateStreamOutput:@"❌ 自定义 API 地址格式不正确，请在 [设置 -> AI模型中心] 检查 API 节点配置。" completion:completion];
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.timeoutInterval = 30.0;
    
    if (apiKey && apiKey.length > 0) {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
    }
    
    NSMutableArray *messages = [NSMutableArray array];
    if (systemPrompt && systemPrompt.length > 0) {
        [messages addObject:@{@"role": @"system", @"content": systemPrompt}];
    }
    [messages addObject:@{@"role": @"user", @"content": message ?: @""}];
    
    NSDictionary *body = @{
        @"model": modelName ?: @"deepseek-chat",
        @"messages": messages,
        @"temperature": @(0.3),
        @"stream": @(NO)
    };
    
    NSError *jsonError = nil;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    
    BOOL isJSTask = (type == 2) || [systemPrompt containsString:@"JavaScript"] || [systemPrompt containsString:@"JS"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data) {
            NSLog(@"[HSBLocalLLM] 自定义 API 请求失败: %@. 正在自动降级...", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (fallback) fallback();
            });
            return;
        }
        
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *content = nil;
        if ([json isKindOfClass:[NSDictionary class]]) {
            NSArray *choices = json[@"choices"];
            if (choices.count > 0) {
                NSDictionary *firstChoice = choices.firstObject;
                NSDictionary *msg = firstChoice[@"message"];
                content = msg[@"content"];
            }
        }
        
        if (content && content.length > 0) {
            if (isJSTask) {
                content = [[HSBBuiltInAIEngine sharedEngine] cleanJSCode:content];
            }
            [[HSBBuiltInAIEngine sharedEngine] simulateStreamOutput:content completion:completion];
        } else {
            NSString *rawStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"[HSBLocalLLM] API 返回格式异常: %@", rawStr);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (fallback) fallback();
            });
        }
    }];
    [task resume];
}

@end
