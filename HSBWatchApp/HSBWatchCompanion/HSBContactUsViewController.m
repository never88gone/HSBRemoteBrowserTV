//
//  HSBContactUsViewController.m
//  HSBWatchCompanion
//

#import "HSBContactUsViewController.h"
#import "HSBThemeManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBContactUsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *dataSource;

@end

@implementation HSBContactUsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"Contact Us", @"联系我们");
    
    self.dataSource = @[
        @{
            @"title": @"GitHub",
            @"value": @"https://github.com/never88gone/HSBRemoteBrowserTV",
            @"icon": @"link.circle.fill",
            @"action": @"github"
        },
        @{
            @"title": L(@"Telegram Channel", @"Telegram 频道"),
            @"value": @"https://t.me/tanghulutvos",
            @"icon": @"paperplane.fill",
            @"action": @"telegram"
        },
        @{
            @"title": L(@"Email", @"官方邮箱"),
            @"value": @"hsb@myit2017.cn",
            @"icon": @"envelope.fill",
            @"action": @"email"
        }
    ];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    [self.view addSubview:self.tableView];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    if (self.tableView) {
        [self.tableView reloadData];
    }
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ContactCell"];
    }
    
    NSDictionary *item = self.dataSource[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    cell.textLabel.textColor = [UIColor whiteColor];
    
    cell.detailTextLabel.text = item[@"value"];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
    cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    cell.imageView.image = [UIImage systemImageNamed:item[@"icon"]];
    cell.imageView.tintColor = palette.primaryColor;
    
    cell.backgroundColor = palette.cardBgColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    UIView *selectedBg = [[UIView alloc] init];
    selectedBg.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
    cell.selectedBackgroundView = selectedBg;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = self.dataSource[indexPath.row];
    NSString *action = item[@"action"];
    NSString *value = item[@"value"];
    
    if ([action isEqualToString:@"github"] || [action isEqualToString:@"telegram"]) {
        [self handleUrlAction:value title:item[@"title"]];
    } else if ([action isEqualToString:@"email"]) {
        [self handleEmailAction:value];
    }
}

- (void)handleUrlAction:(NSString *)urlString title:(NSString *)title {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title
                                                                   message:urlString
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [sheet addAction:[UIAlertAction actionWithTitle:L(@"Open in Browser", @"在浏览器中打开") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *url = [NSURL URLWithString:urlString];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }]];
    
    [sheet addAction:[UIAlertAction actionWithTitle:L(@"Copy Link", @"复制链接") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = urlString;
        [self showToast:L(@"Link copied to clipboard", @"链接已成功复制到剪贴板！")];
    }]];
    
    [sheet addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
    
    // iPad popover 适配
    sheet.popoverPresentationController.sourceView = self.tableView;
    sheet.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:[self.dataSource indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) { return [obj[@"value"] isEqualToString:urlString]; }] inSection:0]];
    
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)handleEmailAction:(NSString *)email {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:L(@"Support Email", @"客服邮箱")
                                                                   message:email
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [sheet addAction:[UIAlertAction actionWithTitle:L(@"Copy Email", @"复制邮箱") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = email;
        [self showToast:L(@"Email copied to clipboard", @"邮箱已成功复制到剪贴板！")];
    }]];
    
    [sheet addAction:[UIAlertAction actionWithTitle:L(@"Open Mail App", @"打开系统邮件发送") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *mailUrlStr = [NSString stringWithFormat:@"mailto:%@", email];
        NSURL *mailUrl = [NSURL URLWithString:mailUrlStr];
        if ([[UIApplication sharedApplication] canOpenURL:mailUrl]) {
            [[UIApplication sharedApplication] openURL:mailUrl options:@{} completionHandler:nil];
        } else {
            [self showToast:L(@"No Mail Client Found", @"未检测到系统邮件客户端")];
        }
    }]];
    
    [sheet addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
    
    // iPad popover 适配
    sheet.popoverPresentationController.sourceView = self.tableView;
    sheet.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]];
    
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showToast:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Success", @"成功")
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
