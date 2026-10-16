//
//  main.m
//  HSBWatchCompanion
//
//  Created by never88gone on 2026/4/1.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
#if TARGET_OS_SIMULATOR
        if (getenv("HOME") == NULL) {
            setenv("HOME", [NSHomeDirectory() UTF8String], 1);
        }
        if (getenv("USER") == NULL) {
            setenv("USER", "simulator_user", 1);
        }
        if (getenv("TMPDIR") == NULL) {
            setenv("TMPDIR", [NSTemporaryDirectory() UTF8String], 1);
        }
#endif
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
