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

@interface SceneDelegate ()
#if DEBUG
@property (nonatomic, strong) dispatch_source_t cmdFileTimer;
#endif
@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Wrap the storyboard root VC in a NavigationController to enable push navigation
    if ([scene isKindOfClass:[UIWindowScene class]]) {
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        // self.window is already created by storyboard auto-init; grab the existing rootVC
        UIViewController *rootVC = self.window.rootViewController;
        if (rootVC && ![rootVC isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:rootVC];
            self.window.rootViewController = nav;
            if (@available(iOS 13.0, *)) {
                self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            }
            self.window.tintColor = [HSBThemeManager tanghuluBrandColor];
            [self.window makeKeyAndVisible];
        } else {
            if (@available(iOS 13.0, *)) {
                self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            }
            self.window.tintColor = [HSBThemeManager tanghuluBrandColor];
        }
    }
    for (UIOpenURLContext *context in connectionOptions.URLContexts) {
        [self handleRemotePairingURL:context.URL];
    }
    for (NSString *arg in [NSProcessInfo processInfo].arguments) {
        if ([arg hasPrefix:@"hsbremote://"]) {
            [self handleRemotePairingURL:[NSURL URLWithString:arg]];
        }
    }
    NSString *testPairURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"UITestPairingURL"];
    if (testPairURL.length > 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"UITestPairingURL"];
        [self handleRemotePairingURL:[NSURL URLWithString:testPairURL]];
    }
#if DEBUG
    [self setupAutomationListener];
#endif
}

#if DEBUG
- (void)setupAutomationListener {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *cmdFile = [docPath stringByAppendingPathComponent:@"remote_cmd.txt"];
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    self.cmdFileTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(self.cmdFileTimer, DISPATCH_TIME_NOW, 150 * NSEC_PER_MSEC, 50 * NSEC_PER_MSEC);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.cmdFileTimer, ^{
        if ([[NSFileManager defaultManager] fileExistsAtPath:cmdFile]) {
            NSError *err = nil;
            NSString *content = [NSString stringWithContentsOfFile:cmdFile encoding:NSUTF8StringEncoding error:&err];
            [[NSFileManager defaultManager] removeItemAtPath:cmdFile error:nil];
            if (content.length > 0) {
                NSString *trimmed = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmed.length > 0) {
                    NSURL *url = [NSURL URLWithString:trimmed];
                    if (url) {
                        NSLog(@"[SceneDelegate] Executing automation command: %@", trimmed);
                        [weakSelf handleRemotePairingURL:url];
                    }
                }
            }
        }
    });
    dispatch_resume(self.cmdFileTimer);
}
#endif

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
        } else if ([[url.host lowercaseString] isEqualToString:@"iptv"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSString *actionName = nil;
            NSString *urlVal = nil;
            NSString *nameVal = nil;
            NSString *epgVal = nil;
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"action"]) actionName = item.value;
                if ([item.name isEqualToString:@"url"]) urlVal = item.value;
                if ([item.name isEqualToString:@"name"]) nameVal = item.value;
                if ([item.name isEqualToString:@"epg"]) epgVal = item.value;
            }
            if ([actionName isEqualToString:@"import_source"] && urlVal.length > 0) {
                NSMutableDictionary *payload = [NSMutableDictionary dictionary];
                payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionIPTVImportSource;
                payload[@"url"] = urlVal;
                payload[@"name"] = nameVal ?: @"港澳台频道 (YanG)";
                if (epgVal.length > 0) {
                    payload[@"epgURL"] = epgVal;
                }
                [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
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
    NSString *testPairURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"UITestPairingURL"];
    if (testPairURL.length > 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"UITestPairingURL"];
        [self handleRemotePairingURL:[NSURL URLWithString:testPairURL]];
    }
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    [[HSBTVOSConnectionManager sharedManager] handleAppDidEnterBackground];
    // Save changes in the application's managed object context when the application transitions to the background.
    [(AppDelegate *)UIApplication.sharedApplication.delegate saveContext];
}


@end
