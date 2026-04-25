#import "HomeConfigEditViewController.h"

static NSString * L_Local(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HomeConfigEditViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *dataArray; // Array of Dictionaries
@end

@implementation HomeConfigEditViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L_Local(@"Edit Home Data", @"编辑首页数据");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L_Local(@"Cancel", @"取消") style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    
    UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc] initWithTitle:L_Local(@"Save & Sync", @"保存并同步") style:UIBarButtonItemStyleDone target:self action:@selector(save)];
    UIBarButtonItem *addSecBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addSection)];
    self.navigationItem.rightBarButtonItems = @[saveBtn, addSecBtn];
    
    _dataArray = [NSMutableArray array];
    [self parseInitialJson];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ItemCell"];
    [self.view addSubview:_tableView];
}

- (void)parseInitialJson {
    if (self.initialJson.length > 0) {
        NSData *data = [self.initialJson dataUsingEncoding:NSUTF8StringEncoding];
        if (data) {
            NSError *err = nil;
            NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&err];
            if (!err && [arr isKindOfClass:[NSArray class]]) {
                self.dataArray = [arr mutableCopy];
            }
        }
    }
    if (self.dataArray.count == 0) {
        [self.dataArray addObject:[@{ @"titleKey": @"New Category", @"items": [NSMutableArray array] } mutableCopy]];
    }
}

- (void)cancel {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)save {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.dataArray options:NSJSONWritingPrettyPrinted error:&error];
    if (data && !error) {
        NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (self.onSaveAndSync) {
            self.onSaveAndSync(jsonString);
        }
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"Failed to build JSON" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)addSection {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L_Local(@"New Category", @"新建分类") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = L_Local(@"Category Name", @"分类名称");
    }];
    [alert addAction:[UIAlertAction actionWithTitle:L_Local(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:L_Local(@"Add", @"添加") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *title = alert.textFields.firstObject.text;
        if (title.length > 0) {
            [self.dataArray addObject:[@{ @"titleKey": title, @"items": [NSMutableArray array] } mutableCopy]];
            [self.tableView reloadData];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *items = self.dataArray[section][@"items"];
    return items.count + 1; // +1 for "Add Item" row
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *key = self.dataArray[section][@"titleKey"];
    NSDictionary *mapping = @{
        @"Popular Video": L_Local(@"Popular Video", @"热门视频"),
        @"Popular Music": L_Local(@"Popular Music", @"热门音乐"),
        @"Popular Live": L_Local(@"Popular Live", @"热门直播"),
        @"Recommended": L_Local(@"Recommended", @"推荐频道")
    };
    return mapping[key] ? mapping[key] : key;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ItemCell" forIndexPath:indexPath];
    cell.detailTextLabel.text = @"";
    cell.imageView.image = nil;
    
    NSArray *items = self.dataArray[indexPath.section][@"items"];
    if (indexPath.row == items.count) {
        cell.textLabel.text = L_Local(@"➕ Add Item", @"➕ 添加新项");
        cell.textLabel.textColor = [UIColor systemBlueColor];
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        NSDictionary *item = items[indexPath.row];
        cell.textLabel.text = item[@"webTitle"];
        cell.textLabel.textColor = [UIColor labelColor];
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSMutableArray *items = [self.dataArray[indexPath.section][@"items"] mutableCopy];
    
    if (indexPath.row == items.count) {
        [self showEditAlertForItem:nil inSection:indexPath.section atRow:indexPath.row];
    } else {
        NSDictionary *item = items[indexPath.row];
        [self showEditAlertForItem:item inSection:indexPath.section atRow:indexPath.row];
    }
}

- (void)showEditAlertForItem:(NSDictionary *)item inSection:(NSInteger)section atRow:(NSInteger)row {
    NSString *title = item ? L_Local(@"Edit Item", @"编辑项目") : L_Local(@"New Item", @"新增项目");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = L_Local(@"Title", @"网页名称 (例如: 哔哩哔哩)");
        if (item) textField.text = item[@"webTitle"];
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = L_Local(@"URL", @"网址 (例如: https://...)");
        textField.keyboardType = UIKeyboardTypeURL;
        if (item) textField.text = item[@"webUrl"];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:L_Local(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:L_Local(@"Save", @"保存") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *webTitle = alert.textFields[0].text;
        NSString *webUrl = alert.textFields[1].text;
        if (webTitle.length > 0 && webUrl.length > 0) {
            NSMutableDictionary *secDict = [self.dataArray[section] mutableCopy];
            NSMutableArray *items = [secDict[@"items"] mutableCopy];
            NSDictionary *newItem = @{ @"webTitle": webTitle, @"webUrl": webUrl };
            if (item) {
                items[row] = newItem;
            } else {
                [items addObject:newItem];
            }
            secDict[@"items"] = items;
            self.dataArray[section] = secDict;
            [self.tableView reloadData];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *items = self.dataArray[indexPath.section][@"items"];
    return indexPath.row < items.count;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSMutableDictionary *secDict = [self.dataArray[indexPath.section] mutableCopy];
        NSMutableArray *items = [secDict[@"items"] mutableCopy];
        [items removeObjectAtIndex:indexPath.row];
        secDict[@"items"] = items;
        self.dataArray[indexPath.section] = secDict;
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 40)];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, tableView.bounds.size.width - 80, 20)];
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    label.textColor = [UIColor secondaryLabelColor];
    label.text = [self tableView:tableView titleForHeaderInSection:section];
    [headerView addSubview:label];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    // Create more spacing on the right by reducing the X origin (from width - 50 to width - 65)
    btn.frame = CGRectMake(tableView.bounds.size.width - 65, 5, 40, 30);
    [btn setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
    btn.tintColor = [UIColor systemRedColor];
    btn.tag = section;
    [btn addTarget:self action:@selector(deleteSection:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:btn];
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (void)deleteSection:(UIButton *)sender {
    NSInteger section = sender.tag;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L_Local(@"Delete Category?", @"确认删除此分类？") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L_Local(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:L_Local(@"Delete", @"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self.dataArray removeObjectAtIndex:section];
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
