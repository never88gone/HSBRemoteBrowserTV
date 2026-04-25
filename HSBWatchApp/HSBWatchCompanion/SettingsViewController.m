#import "SettingsViewController.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"Settings", @"设置");
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    // Add close button if presented modally
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Done", @"完成") style:UIBarButtonItemStyleDone target:self action:@selector(closeSettings)];
}

- (void)closeSettings {
    [self.navigationController popViewControllerAnimated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (indexPath.row == 0) {
        cell.textLabel.text = L(@"Privacy Policy", @"隐私政策");
        cell.imageView.image = [UIImage systemImageNamed:@"hand.raised.fill"];
        cell.imageView.tintColor = [UIColor systemBlueColor];
    } else {
        cell.textLabel.text = L(@"About", @"关于");
        cell.imageView.image = [UIImage systemImageNamed:@"info.circle.fill"];
        cell.imageView.tintColor = [UIColor systemGrayColor];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 0) {
        [self showPrivacyPolicy];
    } else {
        [self showAbout];
    }
}

- (void)showPrivacyPolicy {
    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = L(@"Privacy Policy", @"隐私政策");
    vc.view.backgroundColor = [UIColor systemBackgroundColor];
    
    UITextView *tv = [[UITextView alloc] initWithFrame:vc.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    tv.font = [UIFont systemFontOfSize:15];
    tv.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
    tv.text = @"糖葫芦遥控器（Tanghulu Remote）隐私政策\n\n1. 数据收集与使用\n本应用主要作为外围设备的遥控和体感数据采集工具。我们郑重承诺，本应用不会收集、存储或上传您的任何个人身份信息与隐私。\n所有的控制通信（如控制指令）仅在您的本地局域网内进行设备间的直接传输。\n\n2. 权限说明\n- 本地网络权限：仅用于发现并连接局域网内的智能电视或大屏设备。\n- 传感器权限（如果适用）：仅用于体感交互的数据计算。\n\n3. 信息共享\n我们不会与任何第三方分享您的数据，所有数据均只在本地实时处理。\n\n4. 联系我们\n如有任何问题，可联系官方开发者支持。";
    
    [vc.view addSubview:tv];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showAbout {
    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = L(@"About", @"关于");
    vc.view.backgroundColor = [UIColor systemBackgroundColor];
    
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
    iconView.backgroundColor = [UIColor systemGray5Color];
    iconView.layer.cornerRadius = 22;
    iconView.clipsToBounds = YES;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:iconView];
    
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = appName ?: @"糖葫芦遥控器";
    nameLabel.font = [UIFont boldSystemFontOfSize:24];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:nameLabel];
    
    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.text = [NSString stringWithFormat:@"Version %@ (Build %@)", appVersion, buildNum];
    versionLabel.textColor = [UIColor secondaryLabelColor];
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
