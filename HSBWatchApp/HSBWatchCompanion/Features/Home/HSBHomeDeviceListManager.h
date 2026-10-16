//
//  HSBHomeDeviceListManager.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>
#import "HSBWatchCompanion-Swift.h"

NS_ASSUME_NONNULL_BEGIN

@class HSBHomeDeviceListManager;

@protocol HSBHomeDeviceListManagerDelegate <NSObject>

- (void)deviceListManager:(HSBHomeDeviceListManager *)manager didChangeStatusText:(NSString *)text color:(UIColor *)color;
- (void)deviceListManager:(HSBHomeDeviceListManager *)manager didUpdateDeviceCount:(NSUInteger)count;
- (void)deviceListManager:(HSBHomeDeviceListManager *)manager didConnectSuccessToDevice:(HSBDiscoveredAppleTV *)device;
- (void)deviceListManagerDidRequestQRCodeScanner:(HSBHomeDeviceListManager *)manager;

@end

@interface HSBHomeDeviceListManager : NSObject <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) id<HSBHomeDeviceListManagerDelegate> delegate;
@property (nonatomic, weak) UITableView *tableView;
@property (nonatomic, weak) UIActivityIndicatorView *spinner;
@property (nonatomic, weak) UIViewController *presentingViewController;

@property (nonatomic, readonly) NSMutableArray<HSBDiscoveredAppleTV *> *discoveredDevices;
@property (nonatomic, strong, nullable) NSString *connectingDeviceHost;

- (instancetype)initWithTableView:(UITableView *)tableView
                          spinner:(UIActivityIndicatorView *)spinner
         presentingViewController:(UIViewController *)vc;

- (void)startScanning;
- (void)stopScanning;
- (void)connectToDevice:(HSBDiscoveredAppleTV *)device;
- (void)reopenPINAlertIfNeeded;

@end

NS_ASSUME_NONNULL_END
