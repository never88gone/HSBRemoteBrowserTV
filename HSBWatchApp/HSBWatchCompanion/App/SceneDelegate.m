//
//  SceneDelegate.m
//  HSBWatchCompanion
//
//  Created by never88gone on 2026/4/1.
//

#import "SceneDelegate.h"
#import "AppDelegate.h"
#import "HSBThemeManager.h"
#import "HSBTVOSConnectionManager.h"
#import "HSBWatchSessionManager.h"
#import "HSBWatchCompanion-Swift.h"

@interface SceneDelegate ()

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if ([scene isKindOfClass:[UIWindowScene class]]) {
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (!self.window) {
            self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
            UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
            UIViewController *rootVC = [sb instantiateInitialViewController];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:rootVC];
            self.window.rootViewController = nav;
        } else {
            UIViewController *rootVC = self.window.rootViewController;
            if (rootVC && ![rootVC isKindOfClass:[UINavigationController class]]) {
                UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:rootVC];
                self.window.rootViewController = nav;
            }
        }
        if (@available(iOS 13.0, *)) {
            self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }
        self.window.tintColor = [HSBThemeManager tanghuluBrandColor];
        [self.window makeKeyAndVisible];
        [HSBModernRemoteBridge startAutoDiscoveryAndConnect];
    }
    for (UIOpenURLContext *context in connectionOptions.URLContexts) {
        [self handleRemotePairingURL:context.URL];
    }
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    for (UIOpenURLContext *context in URLContexts) {
        [self handleRemotePairingURL:context.URL];
    }
}

- (void)handleRemotePairingURL:(NSURL *)url {
    NSLog(@"[SceneDelegate] handleRemotePairingURL received: %@", url);
    if ([[url.scheme lowercaseString] isEqualToString:@"hsbremote"]) {
        if ([[url.host lowercaseString] isEqualToString:@"pair"]) {
            NSLog(@"[SceneDelegate] Initiating connectToPairingURL with: %@", url);
            [[HSBTVOSConnectionManager sharedManager] connectToPairingURL:url];
        } else if ([[url.host lowercaseString] isEqualToString:@"pin"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSString *code = nil;
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"code"]) {
                    code = item.value;
                }
            }
            if (code.length > 0) {
                NSLog(@"[SceneDelegate] Received pairing PIN via URL scheme: %@", code);
                [HSBModernRemoteBridge submitNativePIN:code completion:nil];
            }
        } else if ([[url.host lowercaseString] isEqualToString:@"watch"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSString *action = nil;
            CGFloat dy = 0;
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"action"]) action = item.value;
                if ([item.name isEqualToString:@"dy"]) dy = [item.value doubleValue];
            }
            if (action.length > 0) {
                NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithObject:action forKey:@"action"];
                if (dy != 0) {
                    payload[@"dy"] = @(dy);
                }
                NSLog(@"[SceneDelegate] Simulating Watch payload: %@", payload);
                [[HSBWatchSessionManager sharedManager] handleIncomingPayload:payload];
            }
        } else if ([[url.host lowercaseString] isEqualToString:@"guide"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSString *type = @"browser";
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"type"]) {
                    type = item.value ?: @"browser";
                }
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBShowGuideModalNotification"
                                                                object:nil
                                                              userInfo:@{@"type": type}];
        } else if ([[url.host lowercaseString] isEqualToString:@"key"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSString *keyName = nil;
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"name"]) {
                    keyName = item.value;
                }
            }
            NSLog(@"[SceneDelegate] Received remote key command: %@", keyName);
            if (keyName.length > 0) {
                [HSBModernRemoteBridge sendCommandNamed:keyName];
            }
            if ([keyName isEqualToString:@"right"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionRight];
            } else if ([keyName isEqualToString:@"left"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionLeft];
            } else if ([keyName isEqualToString:@"up"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionUp];
            } else if ([keyName isEqualToString:@"down"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionDown];
            } else if ([keyName isEqualToString:@"select"] || [keyName isEqualToString:@"enter"] || [keyName isEqualToString:@"ok"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionSelect];
            } else if ([keyName isEqualToString:@"menu"] || [keyName isEqualToString:@"back"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionMenu];
            } else if ([keyName isEqualToString:@"play"] || [keyName isEqualToString:@"pause"] || [keyName isEqualToString:@"playpause"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionPlay];
            } else if ([keyName isEqualToString:@"forward"] || [keyName isEqualToString:@"seek_forward"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionSeekForward];
            } else if ([keyName isEqualToString:@"backward"] || [keyName isEqualToString:@"seek_backward"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionSeekBackward];
            } else if ([keyName isEqualToString:@"volume_up"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionVolumeUp];
            } else if ([keyName isEqualToString:@"volume_down"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionVolumeDown];
            }
        } else if ([[url.host lowercaseString] isEqualToString:@"browser"] || [[url.host lowercaseString] isEqualToString:@"screen"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSString *action = nil;
            NSString *urlVal = nil;
            NSString *scriptVal = nil;
            CGFloat dx = 0, dy = 0;
            NSInteger modeVal = 1;
            NSString *stateVal = @"began";
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"action"]) action = item.value;
                if ([item.name isEqualToString:@"url"]) urlVal = item.value;
                if ([item.name isEqualToString:@"script"]) scriptVal = item.value;
                if ([item.name isEqualToString:@"dx"]) dx = [item.value doubleValue];
                if ([item.name isEqualToString:@"dy"]) dy = [item.value doubleValue];
                if ([item.name isEqualToString:@"mode"]) modeVal = [item.value integerValue];
                if ([item.name isEqualToString:@"state"]) stateVal = item.value;
            }
            if ([action isEqualToString:@"refresh"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBRefreshScreenChannelNotification" object:nil];
            } else if ([action isEqualToString:@"disconnect"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBDisconnectScreenChannelNotification" object:nil];
            } else if ([action isEqualToString:@"forget"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBForgetScreenChannelNotification" object:nil];
            } else if ([action isEqualToString:@"manage"] || [action isEqualToString:@"sheet"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBShowScreenManageSheetNotification" object:nil];
            } else if ([action isEqualToString:@"open_url"] && urlVal.length > 0) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionOpenUrl withParams:@{@"url": urlVal}];
            } else if ([action isEqualToString:@"scroll"]) {
                [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateActionMacScroll,
                    @"dx": @(dx),
                    @"dy": @(dy)
                }];
            } else if ([action isEqualToString:@"pan"]) {
                [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateActionMacPan,
                    @"dx": @(dx),
                    @"dy": @(dy)
                }];
            } else if ([action isEqualToString:@"drag"]) {
                [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateActionMacDrag,
                    @"state": stateVal ?: @"began",
                    @"dx": @(dx),
                    @"dy": @(dy)
                }];
            } else if ([action isEqualToString:@"tap"]) {
                [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateActionMacTap,
                    @"mode": @(modeVal)
                }];
            } else if ([action isEqualToString:@"reload"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionPageReload];
            } else if ([action isEqualToString:@"home"]) {
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionPageHome];
            }
        } else if ([[url.host lowercaseString] isEqualToString:@"pdf"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSString *action = nil;
            CGFloat x = 0.5, y = 0.5;
            NSString *color = @"#FF3B30";
            CGFloat width = 4.0;
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"action"]) action = item.value;
                if ([item.name isEqualToString:@"x"]) x = [item.value doubleValue];
                if ([item.name isEqualToString:@"y"]) y = [item.value doubleValue];
                if ([item.name isEqualToString:@"color"]) color = item.value;
                if ([item.name isEqualToString:@"width"]) width = [item.value doubleValue];
            }
            if ([action isEqualToString:@"next"]) {
                [HSBModernRemoteBridge sendCommandNamed:@"right"];
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionRight];
            } else if ([action isEqualToString:@"prev"]) {
                [HSBModernRemoteBridge sendCommandNamed:@"left"];
                [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionLeft];
            } else if ([action isEqualToString:@"draw"]) {
                [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPdfDraw,
                    HSBRemotePayloadKeyType: @"point",
                    HSBRemotePayloadKeyX: @(x),
                    HSBRemotePayloadKeyY: @(y),
                    HSBRemotePayloadKeyColor: color,
                    HSBRemotePayloadKeyWidth: @(width)
                }];
            } else if ([action isEqualToString:@"clear"]) {
                [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPdfDraw,
                    HSBRemotePayloadKeyType: HSBRemoteDrawTypeClear
                }];
            }
        } else if ([[url.host lowercaseString] isEqualToString:@"app"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSString *bundleId = nil;
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"bundleId"] || [item.name isEqualToString:@"id"]) {
                    bundleId = item.value;
                }
            }
            if (bundleId.length > 0) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBAppLaunchedNotification"
                                                                    object:bundleId];
            }
        }
    }
}


- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    [[HSBTVOSConnectionManager sharedManager] handleAppWillEnterForeground];
    [HSBModernRemoteBridge startAutoDiscoveryAndConnect];
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    [[HSBTVOSConnectionManager sharedManager] handleAppDidEnterBackground];
    // Save changes in the application's managed object context when the application transitions to the background.
    [(AppDelegate *)UIApplication.sharedApplication.delegate saveContext];
}


@end
