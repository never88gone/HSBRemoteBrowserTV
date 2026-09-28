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
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    for (UIOpenURLContext *context in URLContexts) {
        [self handleRemotePairingURL:context.URL];
    }
}

- (void)handleRemotePairingURL:(NSURL *)url {
    if ([[url.scheme lowercaseString] isEqualToString:@"hsbremote"] &&
        [[url.host lowercaseString] isEqualToString:@"pair"]) {
        [[HSBTVOSConnectionManager sharedManager] connectToPairingURL:url];
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
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.

    // Save changes in the application's managed object context when the application transitions to the background.
    [(AppDelegate *)UIApplication.sharedApplication.delegate saveContext];
}


@end
