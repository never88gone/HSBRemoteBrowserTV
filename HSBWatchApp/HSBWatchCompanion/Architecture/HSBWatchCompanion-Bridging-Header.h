//
//  HSBWatchCompanion-Bridging-Header.h
//  HSBWatchCompanion
//
//  Created for Milestone 1: Swift-ObjC Mixed Architecture.
//

#ifndef HSBWatchCompanion_Bridging_Header_h
#define HSBWatchCompanion_Bridging_Header_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Network/Network.h>

// 辅助包装默认 context 供 Swift 访问
static inline nw_content_context_t HSBGetDefaultMessageContext(void) {
    return NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT;
}

// 1. 核心网络与大屏遥控协议层 (10大类 Action 枚举、Payload 键常量、连接管理器单例)
#import "HSBTVOSConnectionManager.h"

// 2. 现代暗黑调色板与全局主题管理器 (HSBThemeStyle、HSBThemePalette、HSBThemeManager)
#import "HSBThemeManager.h"

// 3. 视图控制器公共基类 (生命周期与主题重写契约)
#import "HSBBaseViewController.h"

// 4. WatchConnectivity 手表端与伴侣端互通会话管理器
#import "HSBWatchSessionManager.h"

// 5. 本地端侧 AI 模型中心与翻译状态桥接
#import "HSBLocalLLMManager.h"

#endif /* HSBWatchCompanion_Bridging_Header_h */
