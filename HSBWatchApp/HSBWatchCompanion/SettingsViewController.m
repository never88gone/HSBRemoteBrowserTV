#import "SettingsViewController.h"
#import "HSBLLMModelCenterViewController.h"
#import "HSBLLMTestViewController.h"
#import "HSBThemeManager.h"
#import "HSBBaseViewController.h"


static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@implementation SettingsViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"Settings", @"设置");
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    // Add close button if presented modally
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Done", @"完成") style:UIBarButtonItemStyleDone target:self action:@selector(closeSettings)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleThemeChanged:) name:HSBThemeChangedNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyThemeColor];
}

- (void)handleThemeChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyThemeColor];
        [self.tableView reloadData];
    });
}

- (void)applyThemeColor {
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    self.navigationController.navigationBar.tintColor = palette.primaryColor;
    self.navigationItem.rightBarButtonItem.tintColor = palette.primaryColor;
    
    NSMutableDictionary *titleAttrs = [NSMutableDictionary dictionary];
    titleAttrs[NSForegroundColorAttributeName] = [UIColor whiteColor];
    self.navigationController.navigationBar.titleTextAttributes = titleAttrs;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.largeTitleTextAttributes = titleAttrs;
    }
    
    self.tableView.backgroundColor = palette.backgroundColor;
    self.view.backgroundColor = palette.backgroundColor;
}

- (void)closeSettings {
    [self.navigationController popViewControllerAnimated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Value1Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Value1Cell"];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.detailTextLabel.text = @"";
    
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    cell.backgroundColor = palette.cardBgColor;
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    
    UIView *selectedBg = [[UIView alloc] init];
    selectedBg.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
    cell.selectedBackgroundView = selectedBg;
    
    if (indexPath.row == 0) {
        cell.textLabel.text = L(@"AI Model Center", @"AI 模型中心");
        cell.imageView.image = [UIImage systemImageNamed:@"cpu.fill"];
        cell.imageView.tintColor = palette.primaryColor;
    } else if (indexPath.row == 1) {
        cell.textLabel.text = L(@"AI Model Testing", @"AI 模型测试");
        cell.imageView.image = [UIImage systemImageNamed:@"sparkles"];
        cell.imageView.tintColor = palette.primaryColor;
    } else if (indexPath.row == 2) {
        cell.textLabel.text = L(@"App Theme", @"应用主题色");
        cell.imageView.image = [UIImage systemImageNamed:@"paintpalette.fill"];
        cell.imageView.tintColor = palette.primaryColor;
        cell.detailTextLabel.text = [HSBThemeManager shared].themeName;
    } else if (indexPath.row == 3) {
        cell.textLabel.text = L(@"Privacy Policy", @"隐私政策");
        cell.imageView.image = [UIImage systemImageNamed:@"hand.raised.fill"];
        cell.imageView.tintColor = palette.primaryColor;
    } else {
        cell.textLabel.text = L(@"About", @"关于");
        cell.imageView.image = [UIImage systemImageNamed:@"info.circle.fill"];
        cell.imageView.tintColor = palette.primaryColor;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 0) {
        HSBLLMModelCenterViewController *vc = [[HSBLLMModelCenterViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    } else if (indexPath.row == 1) {
        HSBLLMTestViewController *vc = [[HSBLLMTestViewController alloc] init];
        vc.sendPayloadBlock = self.sendPayloadBlock;
        [self.navigationController pushViewController:vc animated:YES];
    } else if (indexPath.row == 2) {
        [self showThemeSelection];
    } else if (indexPath.row == 3) {
        [self showPrivacyPolicy];
    } else {
        [self showAbout];
    }
}

- (void)showThemeSelection {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:L(@"Select App Theme", @"设置应用主题色") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray<NSString *> *names = [[HSBThemeManager shared] allThemeNames];
    for (NSInteger i = 0; i < names.count; i++) {
        NSString *name = names[i];
        UIAlertAction *action = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[HSBThemeManager shared] updateTheme:i];
        }];
        [sheet addAction:action];
    }
    
    [sheet addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
    
    // iPad Popover 适配，保障高可用不崩溃
    sheet.popoverPresentationController.sourceView = self.tableView;
    sheet.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]];
    
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showPrivacyPolicy {
    HSBBaseViewController *vc = [[HSBBaseViewController alloc] init];
    vc.title = L(@"Privacy Policy", @"隐私政策");
    
    UITextView *tv = [[UITextView alloc] initWithFrame:vc.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    tv.backgroundColor = [UIColor clearColor];
    tv.textColor = [UIColor whiteColor];
    tv.font = [UIFont systemFontOfSize:15];
    tv.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
    tv.text = @"糖葫芦遥控器（Tanghulu Remote）隐私政策\n\n1. 数据收集与使用\n本应用主要作为外围设备的遥控和体感数据采集工具。我们郑重承诺，本应用不会收集、存储或上传您的任何个人身份信息与隐私。\n所有的控制通信（如控制指令）仅在您的本地局域网内进行设备间的直接传输。\n\n2. 权限说明\n- 本地网络权限：仅用于发现并连接局域网内的智能电视或大屏设备。\n- 传感器权限（如果适用）：仅用于体感交互的数据计算。\n\n3. 信息共享\n我们不会与任何第三方分享您的数据，所有数据均只在本地实时处理。\n\n4. 联系我们\n如有任何问题，可联系官方开发者支持。";
    
    [vc.view addSubview:tv];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showAbout {
    HSBBaseViewController *vc = [[HSBBaseViewController alloc] init];
    vc.title = L(@"About", @"关于");
    
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appName = [infoDict objectForKey:@"CFBundleDisplayName"] ?: [infoDict objectForKey:@"CFBundleName"];
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNum = [infoDict objectForKey:@"CFBundleVersion"];
    
    NSDictionary *iconsDict = infoDict[@"CFBundleIcons"];
    NSDictionary *primaryIconDict = iconsDict[@"CFBundlePrimaryIcon"];
    NSArray *iconFiles = primaryIconDict[@"CFBundleIconFiles"];
    NSString *lastIcon = [iconFiles lastObject];
    UIImage *appIconImage = [UIImage imageNamed:lastIcon];
    if (!appIconImage) {
        appIconImage = [UIImage systemImageNamed:@"tv.circle.fill"];
    }
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:appIconImage];
    iconView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    iconView.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    iconView.layer.cornerRadius = 22;
    iconView.clipsToBounds = YES;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:iconView];
    
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = appName ?: @"糖葫芦遥控器";
    nameLabel.font = [UIFont boldSystemFontOfSize:24];
    nameLabel.textColor = [UIColor whiteColor];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:nameLabel];
    
    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.text = [NSString stringWithFormat:@"Version %@ (Build %@)", appVersion, buildNum];
    versionLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    versionLabel.textAlignment = NSTextAlignmentCenter;
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    versionLabel.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapVersion:)];
    [versionLabel addGestureRecognizer:tap];
    
    [vc.view addSubview:versionLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [iconView.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [iconView.topAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.topAnchor constant:50],
        [iconView.widthAnchor constraintEqualToConstant:100],
        [iconView.heightAnchor constraintEqualToConstant:100],
        
        [nameLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [nameLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:20],
        
        [versionLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [versionLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:10]
    ]];
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)tapVersion:(UITapGestureRecognizer *)sender {
    static NSInteger tapCount = 0;
    tapCount++;
    if (tapCount >= 5) {
        tapCount = 0;
        BOOL current = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowBrowserControlUI"];
        [[NSUserDefaults standardUserDefaults] setBool:!current forKey:@"ShowBrowserControlUI"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Developer Mode", @"开发者模式")
                                                                       message:current ? L(@"Browser Controls Disabled", @"网页控制台已关闭") : L(@"Browser Controls Enabled", @"网页控制台已开启")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [sender.view.window.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

@end
