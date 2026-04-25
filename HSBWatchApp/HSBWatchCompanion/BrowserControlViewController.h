//
//  BrowserControlViewController.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BrowserControlViewController : UIViewController

// Block to send complex structured JSON event payloads
@property (nonatomic, copy) void (^sendPayloadBlock)(NSDictionary *payload);

// Block to send simple string message actions
@property (nonatomic, copy) void (^sendActionBlock)(NSString *actionString);

// Checks if TV is currently connected to warn the user
@property (nonatomic, copy) BOOL (^checkConnectionBlock)(void);

// Opens the TV Home Config editor
@property (nonatomic, copy) void (^editHomeBlock)(void);

@end

NS_ASSUME_NONNULL_END
