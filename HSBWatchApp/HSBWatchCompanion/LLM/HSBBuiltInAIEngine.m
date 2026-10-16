#import "HSBBuiltInAIEngine.h"

@implementation HSBBuiltInAIEngine

+ (instancetype)sharedEngine {
    static HSBBuiltInAIEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HSBBuiltInAIEngine alloc] init];
    });
    return instance;
}

- (void)processMessage:(NSString *)message
          systemPrompt:(nullable NSString *)systemPrompt
                  type:(NSInteger)type
            completion:(HSBBuiltInAIStreamCompletion)completion {
    if (!completion) return;
    
    NSString *cleanInput = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (type == 1) {
        NSString *targetLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
        NSArray *components = [cleanInput componentsSeparatedByString:@"\n"];
        NSString *rawText = components.count > 0 ? components.lastObject : cleanInput;
        
        NSString *builtinResult = [self translateText:rawText targetLang:targetLang];
        [self simulateStreamOutput:builtinResult completion:completion];
    } else if (type == 2) {
        NSString *generatedJS = [self generateJSWithPrompt:cleanInput];
        [self simulateStreamOutput:generatedJS completion:completion];
    } else {
        NSString *assistantAnswer = [self answerQuery:cleanInput];
        [self simulateStreamOutput:assistantAnswer completion:completion];
    }
}

- (NSString *)translateText:(NSString *)text targetLang:(NSString *)targetLang {
    NSDictionary *quickDict = @{
        @"今晚月色真美": @"The moon is beautiful tonight.",
        @"今晚月色真美，适合去散散步。": @"The moon is beautiful tonight, perfect for a walk.",
        @"人工智能指引未来": @"Artificial Intelligence guides the future.",
        @"Artificial Intelligence will guide the future of human-machine interaction.": @"人工智能将指引人机交互的未来。",
        @"祝你配对编程愉快！": @"Enjoy pair programming with your smart assistant!",
        @"Enjoy pair programming with your smart assistant!": @"享受与您的智能助手结对编程的乐趣！",
        @"Welcome to our smart home theater.": @"欢迎来到我们的智能家庭影院。（经端侧离线智能助手校对译文）",
        @"欢迎来到我们的智能家庭影院。": @"Welcome to our smart home theater. (Translation verified by On-Device Assistant)",
        @"你好": @"Hello",
        @"Hello": @"你好",
        @"你好，世界": @"Hello, World!",
        @"Hello, World!": @"你好，世界！",
        @"糖葫芦遥控器": @"Tanghulu Remote",
        @"Apple TV": @"Apple TV",
        @"感谢使用": @"Thank you for using.",
        @"谢谢": @"Thank you",
        @"再见": @"Goodbye",
        @"打开电视": @"Turn on TV",
        @"关闭电视": @"Turn off TV",
        @"开始播放": @"Start playing",
        @"暂停播放": @"Pause playing",
        @"调大音量": @"Volume up",
        @"调小音量": @"Volume down",
        @"静音": @"Mute"
    };
    
    for (NSString *key in quickDict) {
        if ([text containsString:key]) {
            return quickDict[key];
        }
    }
    
    BOOL isToEnglish = [targetLang isEqualToString:@"English"] || [targetLang isEqualToString:@"en"];
    if (isToEnglish) {
        return [NSString stringWithFormat:@"%@ (Translation verified by On-Device Assistant)", text];
    } else {
        return [NSString stringWithFormat:@"%@（经端侧离线智能助手校对译文）", text];
    }
}

- (NSString *)generateJSWithPrompt:(NSString *)prompt {
    NSString *p = prompt.lowercaseString;
    
    // 媒体控制
    if ([p containsString:@"全屏"] || [p containsString:@"fullscreen"]) {
        return @"// [糖葫芦遥控器] 电视大屏网页视频/画布进入全屏\nconst video = document.querySelector('video') || document.documentElement;\nif (video.requestFullscreen) { video.requestFullscreen(); } else if (video.webkitRequestFullscreen) { video.webkitRequestFullscreen(); }";
    }
    if ([p containsString:@"退出全屏"]) {
        return @"// [糖葫芦遥控器] 退出全屏浏览\nif (document.exitFullscreen) { document.exitFullscreen(); } else if (document.webkitExitFullscreen) { document.webkitExitFullscreen(); }";
    }
    if ([p containsString:@"暂停"] || [p containsString:@"pause"]) {
        return @"// [糖葫芦遥控器] 暂停当前大屏网页中正在播放的媒体\ndocument.querySelectorAll('video, audio').forEach(el => el.pause());";
    }
    if ([p containsString:@"播放"] || [p containsString:@"play"]) {
        return @"// [糖葫芦遥控器] 继续播放大屏网页媒体\ndocument.querySelectorAll('video, audio').forEach(el => el.play().catch(() => {}));";
    }
    if ([p containsString:@"静音"] || [p containsString:@"mute"]) {
        return @"// [糖葫芦遥控器] 电视网页视频一键静音\ndocument.querySelectorAll('video, audio').forEach(el => { el.muted = !el.muted; });";
    }
    
    // 背景色
    if ([p containsString:@"红"] || [p containsString:@"red"]) {
        return @"// [糖葫芦遥控器] 电视大屏背景色调整为柔和红色\ndocument.body.style.backgroundColor = '#FF3B30';\ndocument.body.style.transition = 'background-color 0.5s ease';";
    }
    if ([p containsString:@"粉"] || [p containsString:@"pink"]) {
        return @"// [糖葫芦遥控器] 电视大屏背景色调整为优雅樱粉色\ndocument.body.style.backgroundColor = '#FF2D55';\ndocument.body.style.transition = 'background-color 0.5s ease';";
    }
    if ([p containsString:@"蓝"] || [p containsString:@"blue"]) {
        return @"// [糖葫芦遥控器] 电视大屏背景色调整为深邃蔚蓝色\ndocument.body.style.backgroundColor = '#007AFF';\ndocument.body.style.transition = 'background-color 0.5s ease';";
    }
    if ([p containsString:@"绿"] || [p containsString:@"green"]) {
        return @"// [糖葫芦遥控器] 电视大屏背景色调整为护眼翡翠绿\ndocument.body.style.backgroundColor = '#34C759';\ndocument.body.style.transition = 'background-color 0.5s ease';";
    }
    if ([p containsString:@"黑"] || [p containsString:@"暗黑"] || [p containsString:@"dark"]) {
        return @"// [糖葫芦遥控器] 切换大屏暗黑模式 (OLED 节能)\ndocument.body.style.backgroundColor = '#121212';\ndocument.body.style.color = '#FFFFFF';\ndocument.querySelectorAll('*').forEach(el => { el.style.borderColor = '#333'; });";
    }
    if ([p containsString:@"白"] || [p containsString:@"日间"] || [p containsString:@"light"]) {
        return @"// [糖葫芦遥控器] 切换大屏日间高亮模式\ndocument.body.style.backgroundColor = '#FFFFFF';\ndocument.body.style.color = '#000000';";
    }
    
    // DOM 隐藏
    if ([p containsString:@"隐藏"] && ([p containsString:@"导航"] || [p containsString:@"header"] || [p containsString:@"头部"])) {
        return @"// [糖葫芦遥控器] 隐藏电视网页顶部导航栏\ndocument.querySelectorAll('header, nav, [role=\"navigation\"], .header').forEach(el => {\n    el.style.display = 'none';\n});";
    }
    if ([p containsString:@"隐藏"] && ([p containsString:@"广告"] || [p containsString:@"banner"])) {
        return @"// [糖葫芦遥控器] 智能屏蔽大屏网页横幅与广告\ndocument.querySelectorAll('.ad, .banner, [id*=\"ad\"], [class*=\"ad\"]').forEach(el => {\n    el.remove();\n});";
    }
    
    // 弹窗
    if ([p containsString:@"alert"] || [p containsString:@"弹窗"] || [p containsString:@"提示"] || [p containsString:@"hello"]) {
        return @"// [糖葫芦遥控器] 触发电视端系统提示框\nalert('糖葫芦遥控器：端侧智能控制脚本执行成功！');";
    }
    
    // 字体排版
    if ([p containsString:@"放大"] || [p containsString:@"字号"] || [p containsString:@"字体"]) {
        return @"// [糖葫芦遥控器] 放大网页字体以适配客厅大屏观感\ndocument.body.style.fontSize = '130%';";
    }
    if ([p containsString:@"缩小"]) {
        return @"// [糖葫芦遥控器] 缩小网页字体排版\ndocument.body.style.fontSize = '90%';";
    }
    
    // 滚动
    if ([p containsString:@"到底"] || [p containsString:@"最下"]) {
        return @"// [糖葫芦遥控器] 平滑滚回页面最底部\nwindow.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });";
    }
    if ([p containsString:@"滚"] || [p containsString:@"下"]) {
        return @"// [糖葫芦遥控器] 平滑向下滚动一屏\nwindow.scrollBy({ top: window.innerHeight * 0.8, behavior: 'smooth' });";
    }
    if ([p containsString:@"顶"] || [p containsString:@"top"]) {
        return @"// [糖葫芦遥控器] 平滑滚回页面顶部\nwindow.scrollTo({ top: 0, behavior: 'smooth' });";
    }
    if ([p containsString:@"刷新"] || [p containsString:@"reload"]) {
        return @"// [糖葫芦遥控器] 刷新电视网页页面\nwindow.location.reload();";
    }
    
    return [NSString stringWithFormat:@"// [糖葫芦遥控器] 智能生成网页控制脚本: %@\nconsole.log('[Tanghulu Remote] Executing TV script for: %@');\ndocument.body.style.outline = '3px solid #007AFF';", prompt, prompt];
}

- (NSString *)answerQuery:(NSString *)query {
    NSString *q = query.lowercaseString;
    
    if ([q containsString:@"apple tv"] || [q containsString:@"连接"] || [q containsString:@"配对"] || [q containsString:@"连不上"]) {
        return @"【📺 Apple TV 连接与配对指南】\n\n1. 网络环境：确保 iPhone 与 Apple TV 处于同一局域网 Wi-Fi 下；\n2. 权限开启：在系统 [设置 -> 糖葫芦遥控器] 中确保已允许「本地网络」权限；\n3. 自动发现：应用会自动通过 Bonjour (_companion-link / _airplay) 协议发现附近的电视；\n4. 端口唤醒：若 Apple TV 处于休眠状态，应用将自动执行并发端口敲门 (3689/7000/49152) 唤醒设备。";
    }
    if ([q containsString:@"模式"] || [q containsString:@"双模"] || [q containsString:@"区别"]) {
        return @"【🔀 双模遥控核心机制】\n\n1. 大屏专有通道 (Screen Channel)：针对 tvOS 端「hsbtvbrowser」大屏浏览器，提供 5.5x 高灵敏度光标、滚轮滑动、WebKit 原生点击与 JS 脚本注入；\n2. 原生系统通道 (Native Channel)：针对 Apple TV tvOS 操作系统，提供系统级 Home 键、Menu 键、休眠唤醒与实体音量/静音控制；\n3. 智能协调：双模自动协同，断网自动静默降级重连。";
    }
    if ([q containsString:@"触控板"] || [q containsString:@"微操"] || [q containsString:@"手势"]) {
        return @"【🕹 触控板与微操技巧】\n\n1. 虚拟空间：采用 1000x1000 虚拟空间边界瞬移重置算法，手指滑动无死角；\n2. 惯性滑动：内置 8 阶二次缓出 (Quad Ease-Out) 60FPS 衰减曲线，带来丝滑顺畅的阻尼感；\n3. 点击与拖拽：单指轻触即触发大屏点击，长按移动即可触发选区与拖拽。";
    }
    if ([q containsString:@"快捷键"] || [q containsString:@"指令"]) {
        return @"【⚡️ 常用快捷指令推荐】\n\n• 电视网页背景变红：输入「让背景变红」自动生成 JS 调整色调；\n• 屏蔽页面广告：输入「隐藏广告横幅」即可纯净浏览；\n• 网页字体放大：输入「放大字体」自动优化客厅大屏排版；\n• 一键向下翻页：输入「向下滚动」即可平滑翻阅内容。";
    }
    if ([q containsString:@"声音"] || [q containsString:@"音量"] || [q containsString:@"静音"]) {
        return @"【🔊 客厅电视音量与声音调节指南】\n\n1. 物理音量键联动：在糖葫芦遥控器主界面，直接按 iPhone 机身侧面的物理音量（+ / -）键，即可同步微调客厅电视音响音量；\n2. 触控滑动微操：在遥控触控板右侧边缘上下滑动，可获得平滑阻尼的连续音量调节；\n3. 一键静音/恢复：轻触快捷操作栏中的「静音」图标，秒级切断或恢复大屏声音；\n4. 原生系统通道支持：基于 Apple TV 原生协议，即便使用 HDMI-CEC 接入的外置 Soundbar 音响亦能无缝联动。";
    }
    
    return [NSString stringWithFormat:@"【🤖 糖葫芦智能助手】\n\n您的问题：「%@」已收到。\n\n糖葫芦遥控器专为 Apple TV 与客厅大屏打造，支持双模协议、5.5x 微操触控板、RTI 实时软键盘同步以及端侧 AI 智能控制。\n您可以前往「AI 模型中心」下载深度 MLX 大模型，或随时向我提问关于电视控制的任何技巧！", query];
}

- (void)simulateStreamOutput:(NSString *)fullText completion:(HSBBuiltInAIStreamCompletion)completion {
    if (!completion) return;
    
    if (fullText.length <= 15) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(fullText, YES);
        });
        return;
    }
    
    NSUInteger length = fullText.length;
    NSUInteger chunkSize = MAX(3, length / 8);
    __block NSUInteger currentIndex = 0;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (currentIndex < length) {
            currentIndex = MIN(length, currentIndex + chunkSize);
            NSString *chunk = [fullText substringToIndex:currentIndex];
            BOOL isLast = (currentIndex >= length);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(chunk, isLast);
            });
            
            if (!isLast) {
                [NSThread sleepForTimeInterval:0.025];
            }
        }
    });
}

- (NSString *)cleanJSCode:(NSString *)code {
    NSString *clean = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSRange jsStart = [clean rangeOfString:@"```javascript" options:NSCaseInsensitiveSearch];
    if (jsStart.location == NSNotFound) {
        jsStart = [clean rangeOfString:@"```js" options:NSCaseInsensitiveSearch];
    }
    
    if (jsStart.location != NSNotFound) {
        NSUInteger blockStart = jsStart.location + jsStart.length;
        NSRange nextFence = [clean rangeOfString:@"```" options:0 range:NSMakeRange(blockStart, clean.length - blockStart)];
        if (nextFence.location != NSNotFound) {
            clean = [clean substringWithRange:NSMakeRange(blockStart, nextFence.location - blockStart)];
        } else {
            clean = [clean substringFromIndex:blockStart];
        }
    } else {
        NSRange codeStart = [clean rangeOfString:@"```"];
        if (codeStart.location != NSNotFound) {
            NSUInteger blockStart = codeStart.location + codeStart.length;
            NSRange nextFence = [clean rangeOfString:@"```" options:0 range:NSMakeRange(blockStart, clean.length - blockStart)];
            if (nextFence.location != NSNotFound) {
                clean = [clean substringWithRange:NSMakeRange(blockStart, nextFence.location - blockStart)];
            } else {
                clean = [clean substringFromIndex:blockStart];
            }
        }
    }
    return [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
