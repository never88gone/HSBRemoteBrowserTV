//
//  HSBHomeDeviceListManager.m
//  HSBWatchCompanion
//

#import "HSBHomeDeviceListManager.h"
#import "HSBThemeManager.h"
#import "HSBTVOSConnectionManager.h"

static inline NSString * HSBLocalText(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBHomeDeviceListManager ()

@property (nonatomic, strong) NSMutableArray<HSBDiscoveredAppleTV *> *discoveredDevices;

@end

@implementation HSBHomeDeviceListManager

- (instancetype)initWithTableView:(UITableView *)tableView
                          spinner:(UIActivityIndicatorView *)spinner
         presentingViewController:(UIViewController *)vc {
    self = [super init];
    if (self) {
        _tableView = tableView;
        _spinner = spinner;
        _presentingViewController = vc;
        _discoveredDevices = [NSMutableArray array];
        
        tableView.dataSource = self;
        tableView.delegate = self;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNativePINRequired:) name:@"HSBAppleTVNativePINRequiredNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNativePINSubmitting:) name:@"HSBAppleTVNativePINSubmittingNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNativePINCancelled:) name:@"HSBAppleTVNativePINCancelledNotification" object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)startScanning {
    [self.spinner startAnimating];
    self.spinner.hidden = NO;
    self.tableView.backgroundView.hidden = YES;
    
    [self notifyStatus:HSBLocalText(@"🟡 Scanning Apple TV Hardware...", @"🟡 正在扫描局域网 Apple TV 硬件设备...") color:[UIColor systemYellowColor]];
    
    __weak typeof(self) weakSelf = self;
    [[HSBAppleTVDiscovery shared] startScanningWithOnChange:^(NSArray<HSBDiscoveredAppleTV *> *devices) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.discoveredDevices removeAllObjects];
            [weakSelf.discoveredDevices addObjectsFromArray:devices];
            [weakSelf.tableView reloadData];
            
            if (weakSelf.discoveredDevices.count > 0) {
                [weakSelf.spinner stopAnimating];
                weakSelf.spinner.hidden = YES;
                weakSelf.tableView.backgroundView.hidden = YES;
                
                NSString *fmt = HSBLocalText(@"🟢 Found %lu Apple TV Device(s)", @"🟢 已发现 %lu 台 Apple TV 硬件设备");
                NSString *text = [NSString stringWithFormat:fmt, (unsigned long)weakSelf.discoveredDevices.count];
                [weakSelf notifyStatus:text color:[UIColor systemGreenColor]];
                [weakSelf.delegate deviceListManager:weakSelf didUpdateDeviceCount:weakSelf.discoveredDevices.count];
            }
        });
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.discoveredDevices.count == 0) {
            [weakSelf.spinner stopAnimating];
            weakSelf.spinner.hidden = YES;
            weakSelf.tableView.backgroundView.hidden = NO;
            [weakSelf notifyStatus:HSBLocalText(@"⚪️ Scanning idle (Tap to retry)", @"⚪️ 扫描完成 (未发现 Apple TV 硬件)") color:[[UIColor whiteColor] colorWithAlphaComponent:0.6]];
        }
    });
}

- (void)stopScanning {
    [[HSBAppleTVDiscovery shared] stopScanning];
    [self.spinner stopAnimating];
    self.spinner.hidden = YES;
}

- (void)connectToDevice:(HSBDiscoveredAppleTV *)device {
    if (!device) return;
    NSLog(@"[ATV_CONNECT] connectToDevice: %@", device.name);
    
    if ([HSBModernRemoteBridge isLaunchAnimationActive]) {
        NSLog(@"[ATV_CONNECT] Launch animation active, deferring connectToDevice until finish...");
        __weak typeof(self) weakSelf = self;
        __block id obs = nil;
        obs = [[NSNotificationCenter defaultCenter] addObserverForName:@"HSBLaunchAnimationDidFinishNotification" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [[NSNotificationCenter defaultCenter] removeObserver:obs];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf connectToDevice:device];
            });
        }];
        return;
    }
    
    if ([HSBModernRemoteBridge isUnifiedConnected]) {
        [self.delegate deviceListManager:self didConnectSuccessToDevice:device];
        return;
    }
    
    if (self.connectingDeviceHost && [self.connectingDeviceHost isEqualToString:device.host]) {
        return;
    }
    
    self.connectingDeviceHost = device.host;
    [self.tableView reloadData];
    
    BOOL isMac = device.isMacDevice;
    NSString *statusStr = isMac ?
        [NSString stringWithFormat:HSBLocalText(@"🟡 Connecting to Mac %@...", @"🟡 正在连接 Mac %@..."), device.name] :
        [NSString stringWithFormat:HSBLocalText(@"🟡 Connecting to Apple TV %@...", @"🟡 正在连接 Apple TV %@..."), device.name];
    [self notifyStatus:statusStr color:[UIColor systemYellowColor]];
    
    __weak typeof(self) weakSelf = self;
    [HSBModernRemoteBridge connectToDiscoveredDevice:device timeout:15.0 completion:^(BOOL success, NSString * _Nullable errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.connectingDeviceHost = nil;
            [weakSelf.tableView reloadData];
            
            if (success) {
                NSString *okStr = [NSString stringWithFormat:HSBLocalText(@"🟢 Connected to %@", @"🟢 已连接至 %@"), device.name];
                [weakSelf notifyStatus:okStr color:[UIColor systemGreenColor]];
                [weakSelf.delegate deviceListManager:weakSelf didConnectSuccessToDevice:device];
            } else {
                NSString *failStr = [NSString stringWithFormat:HSBLocalText(@"🔴 Failed to connect to %@", @"🔴 连接 %@ 失败"), device.name];
                [weakSelf notifyStatus:failStr color:[UIColor systemRedColor]];
                [weakSelf showConnectionFailureGuideForDevice:device isMac:isMac];
            }
        });
    }];
}

- (void)showConnectionFailureGuideForDevice:(HSBDiscoveredAppleTV *)device isMac:(BOOL)isMac {
    if (!self.presentingViewController) return;
    
    if (isMac) {
        NSString *macMsg = [NSString stringWithFormat:HSBLocalText(@"未能与 “%@” 建立原生媒体控制通道。\n\n• 开启免装软件控制通道：\n请确认 Mac 的 [系统设置] -> [通用] -> [隔空播放与接力] 中，已开启【隔空播放接收器】；\n\n• 检查网络环境：\n请确保手机与 Mac 连接在同一局域网 Wi-Fi 下。", @"未能与 “%@” 建立原生媒体控制通道。\n\n• 开启免装软件控制通道：\n请确认 Mac 的 [系统设置] -> [通用] -> [隔空播放与接力] 中，已开启【隔空播放接收器】；\n\n• 检查网络环境：\n请确保手机与 Mac 连接在同一局域网 Wi-Fi 下。"), device.name];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:HSBLocalText(@"Mac 连接指引", @"Mac 连接指引") message:macMsg preferredStyle:UIAlertControllerStyleAlert];
        __weak typeof(self) weakSelf = self;
        [alert addAction:[UIAlertAction actionWithTitle:HSBLocalText(@"🔄 重试连接", @"🔄 重试连接") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf connectToDevice:device];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:HSBLocalText(@"好的", @"好的") style:UIAlertActionStyleCancel handler:nil]];
        [self.presentingViewController presentViewController:alert animated:YES completion:nil];
    } else {
        NSString *msg = [NSString stringWithFormat:HSBLocalText(@"未能与 “%@” 建立连接。\n\n• 如需遥控 Apple TV 全局系统：\n请点击【重试连接】，电视屏幕将弹出 4 位配对码，在手机输入即可完成永久绑定；\n\n• 如需控制电视上的【糖葫芦浏览器】网页：\n请在电视打开应用后，点击下方【扫码连接专属浏览器】。", @"未能与 “%@” 建立连接。\n\n• 如需遥控 Apple TV 全局系统：\n请点击【重试连接】，电视屏幕将弹出 4 位配对码，在手机输入即可完成永久绑定；\n\n• 如需控制电视上的【糖葫芦浏览器】网页：\n请在电视打开应用后，点击下方【扫码连接专属浏览器】。"), device.name];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:HSBLocalText(@"电视连接指引", @"电视连接指引") message:msg preferredStyle:UIAlertControllerStyleAlert];
        __weak typeof(self) weakSelf = self;
        [alert addAction:[UIAlertAction actionWithTitle:HSBLocalText(@"🔄 重试连接", @"🔄 重试连接") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf connectToDevice:device];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:HSBLocalText(@"📷 扫码连接专属浏览器", @"📷 扫码连接专属浏览器") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf.delegate deviceListManagerDidRequestQRCodeScanner:weakSelf];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:HSBLocalText(@"好的", @"好的") style:UIAlertActionStyleCancel handler:nil]];
        [self.presentingViewController presentViewController:alert animated:YES completion:nil];
    }
}

- (void)reopenPINAlertIfNeeded {
    [HSBModernRemoteBridge reopenNativePINAlertIfNeeded];
}

- (void)notifyStatus:(NSString *)text color:(UIColor *)color {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate deviceListManager:self didChangeStatusText:text color:color];
    });
}

#pragma mark - Notifications
- (void)handleNativePINRequired:(NSNotification *)note {
    [self notifyStatus:HSBLocalText(@"🟡 请在屏幕弹窗中输入电视上的 4 位 PIN 码...", @"🟡 请在屏幕弹窗中输入电视上的 4 位 PIN 码...") color:[UIColor systemYellowColor]];
}

- (void)handleNativePINSubmitting:(NSNotification *)note {
    [self notifyStatus:HSBLocalText(@"🟡 正在验证 PIN 码并建立加密通道...", @"🟡 正在验证 PIN 码并建立加密通道...") color:[UIColor systemYellowColor]];
}

- (void)handleNativePINCancelled:(NSNotification *)note {
    self.connectingDeviceHost = nil;
    [self.tableView reloadData];
    [self notifyStatus:HSBLocalText(@"⚪️ 已取消配对", @"⚪️ 已取消配对") color:[[UIColor whiteColor] colorWithAlphaComponent:0.6]];
}

#pragma mark - UITableView DataSource & Delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.discoveredDevices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"TVCellSubtitle";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    }
    cell.backgroundColor = [UIColor clearColor];
    
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    UIView *selectedBg = [[UIView alloc] init];
    selectedBg.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
    cell.selectedBackgroundView = selectedBg;
    
    if (indexPath.row < self.discoveredDevices.count) {
        HSBDiscoveredAppleTV *device = self.discoveredDevices[indexPath.row];
        cell.textLabel.text = device.name;
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        cell.textLabel.textColor = [UIColor whiteColor];
        
        cell.imageView.image = [UIImage systemImageNamed:device.deviceCategoryIconName];
        cell.imageView.tintColor = palette.primaryColor;
        
        if (self.connectingDeviceHost && [self.connectingDeviceHost isEqualToString:device.host]) {
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            spinner.color = palette.primaryColor;
            [spinner startAnimating];
            cell.accessoryView = spinner;
            cell.detailTextLabel.text = HSBLocalText(@"Connecting...", @"正在连接...");
            cell.detailTextLabel.textColor = palette.primaryColor;
        } else {
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.detailTextLabel.text = device.displaySubtitle;
            cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.65];
        }
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    
    if (indexPath.row < self.discoveredDevices.count) {
        HSBDiscoveredAppleTV *selectedDevice = self.discoveredDevices[indexPath.row];
        [self connectToDevice:selectedDevice];
    }
}

@end
