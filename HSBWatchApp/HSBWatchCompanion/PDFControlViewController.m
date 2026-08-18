//
//  PDFControlViewController.m
//  HSBWatchCompanion
//

#import "PDFControlViewController.h"
#import "HSBTVOSConnectionManager.h"
#import "HSBThemeManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface PDFControlViewController ()

// 绘制画布与核心属性
@property (nonatomic, strong) UIImageView *canvasView;
@property (nonatomic, assign) CGPoint lastPoint;
@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, copy) NSString *strokeColorKey;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) BOOL isEraserMode;

// 历史回退栈 (Undo Stack)
@property (nonatomic, strong) NSMutableArray<UIImage *> *undoStack;

// UI 组件
@property (nonatomic, strong) UIView *topToolBar;
@property (nonatomic, strong) UIScrollView *paletteScrollView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *colorButtons;
@property (nonatomic, strong) UISegmentedControl *widthSegment;
@property (nonatomic, strong) UIButton *eraserToggleBtn;
@property (nonatomic, strong) UIButton *undoBtn;
@property (nonatomic, strong) UIButton *clearBtn;

// 底部翻页控制栏
@property (nonatomic, strong) UIView *bottomControlBar;
@property (nonatomic, strong) UIButton *prevPageBtn;
@property (nonatomic, strong) UIButton *nextPageBtn;
@property (nonatomic, strong) UILabel *titleTipLabel;

@end

@implementation PDFControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.undoStack = [NSMutableArray array];
    self.colorButtons = [NSMutableArray array];
    
    // 默认画笔配置
    self.strokeColor = [UIColor systemRedColor];
    self.strokeColorKey = HSBRemoteDrawColorRed;
    self.strokeWidth = 4.0;
    self.isEraserMode = NO;
    
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    
    [self setupCanvas];
    [self setupTopToolBar];
    [self setupBottomControlBar];
    
    [self applyThemeStyle];
}

#pragma mark - UI Setup

- (void)setupCanvas {
    self.canvasView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.canvasView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.canvasView.userInteractionEnabled = YES;
    self.canvasView.backgroundColor = [UIColor blackColor];
    self.canvasView.layer.cornerRadius = 16;
    self.canvasView.layer.masksToBounds = YES;
    self.canvasView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor;
    self.canvasView.layer.borderWidth = 1.0;
    self.canvasView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.canvasView];
    
    // 提示手绘同步的水印
    self.titleTipLabel = [[UILabel alloc] init];
    self.titleTipLabel.text = L(@"✏️ Draw / Annotate (Syncing to TV in Real-time)", @"✏️ 屏幕手绘批注 (实时无缝同步至电视)");
    self.titleTipLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35];
    self.titleTipLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.titleTipLabel.textAlignment = NSTextAlignmentCenter;
    self.titleTipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.canvasView addSubview:self.titleTipLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleTipLabel.centerXAnchor constraintEqualToAnchor:self.canvasView.centerXAnchor],
        [self.titleTipLabel.centerYAnchor constraintEqualToAnchor:self.canvasView.centerYAnchor]
    ]];
}

- (void)setupTopToolBar {
    self.topToolBar = [[UIView alloc] init];
    self.topToolBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.65];
    self.topToolBar.layer.cornerRadius = 20;
    self.topToolBar.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    self.topToolBar.layer.borderWidth = 1.0;
    self.topToolBar.clipsToBounds = YES;
    self.topToolBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.topToolBar];
    
    // 1. 多色调色盘 (Red, Blue, Green, Yellow, White, Black)
    NSArray *colorPalette = @[
        @{@"color": [UIColor systemRedColor], @"key": HSBRemoteDrawColorRed, @"name": @"red"},
        @{@"color": [UIColor systemBlueColor], @"key": HSBRemoteDrawColorBlue, @"name": @"blue"},
        @{@"color": [UIColor systemGreenColor], @"key": HSBRemoteDrawColorGreen, @"name": @"green"},
        @{@"color": [UIColor systemYellowColor], @"key": HSBRemoteDrawColorYellow, @"name": @"yellow"},
        @{@"color": [UIColor whiteColor], @"key": HSBRemoteDrawColorWhite, @"name": @"white"},
        @{@"color": [UIColor colorWithWhite:0.25 alpha:1.0], @"key": HSBRemoteDrawColorBlack, @"name": @"black"}
    ];
    
    UIStackView *paletteStack = [[UIStackView alloc] init];
    paletteStack.axis = UILayoutConstraintAxisHorizontal;
    paletteStack.spacing = 10;
    paletteStack.distribution = UIStackViewDistributionFillEqually;
    paletteStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.topToolBar addSubview:paletteStack];
    
    for (int i = 0; i < colorPalette.count; i++) {
        NSDictionary *item = colorPalette[i];
        UIColor *col = item[@"color"];
        NSString *key = item[@"key"];
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = col;
        btn.layer.cornerRadius = 14;
        btn.layer.masksToBounds = YES;
        btn.tag = i;
        btn.accessibilityLabel = key;
        
        // 初始选中红色
        if (i == 0) {
            btn.layer.borderColor = [UIColor whiteColor].CGColor;
            btn.layer.borderWidth = 3.0;
            btn.transform = CGAffineTransformMakeScale(1.15, 1.15);
        } else {
            btn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
            btn.layer.borderWidth = 1.0;
        }
        
        [btn addTarget:self action:@selector(colorSelected:) forControlEvents:UIControlEventTouchUpInside];
        [self.colorButtons addObject:btn];
        [paletteStack addArrangedSubview:btn];
        
        [NSLayoutConstraint activateConstraints:@[
            [btn.widthAnchor constraintEqualToConstant:28],
            [btn.heightAnchor constraintEqualToConstant:28]
        ]];
    }
    
    // 2. 笔刷粗细切换 (2pt / 4pt / 8pt / 14pt)
    self.widthSegment = [[UISegmentedControl alloc] initWithItems:@[@"2pt", @"4pt", @"8pt", @"14pt"]];
    self.widthSegment.selectedSegmentIndex = 1; // 4pt
    [self.widthSegment addTarget:self action:@selector(widthSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.widthSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.topToolBar addSubview:self.widthSegment];
    
    // 3. 橡皮擦开关
    self.eraserToggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *eraserConfig = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [self.eraserToggleBtn setImage:[UIImage systemImageNamed:@"eraser" withConfiguration:eraserConfig] forState:UIControlStateNormal];
    self.eraserToggleBtn.tintColor = [UIColor whiteColor];
    self.eraserToggleBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    self.eraserToggleBtn.layer.cornerRadius = 16;
    [self.eraserToggleBtn addTarget:self action:@selector(toggleEraserMode) forControlEvents:UIControlEventTouchUpInside];
    self.eraserToggleBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.topToolBar addSubview:self.eraserToggleBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.topToolBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.topToolBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.topToolBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.topToolBar.heightAnchor constraintEqualToConstant:48],
        
        [paletteStack.centerYAnchor constraintEqualToAnchor:self.topToolBar.centerYAnchor],
        [paletteStack.leadingAnchor constraintEqualToAnchor:self.topToolBar.leadingAnchor constant:12],
        
        [self.widthSegment.centerYAnchor constraintEqualToAnchor:self.topToolBar.centerYAnchor],
        [self.widthSegment.leadingAnchor constraintEqualToAnchor:paletteStack.trailingAnchor constant:12],
        [self.widthSegment.heightAnchor constraintEqualToConstant:28],
        [self.widthSegment.widthAnchor constraintEqualToConstant:140],
        
        [self.eraserToggleBtn.centerYAnchor constraintEqualToAnchor:self.topToolBar.centerYAnchor],
        [self.eraserToggleBtn.trailingAnchor constraintEqualToAnchor:self.topToolBar.trailingAnchor constant:-10],
        [self.eraserToggleBtn.widthAnchor constraintEqualToConstant:32],
        [self.eraserToggleBtn.heightAnchor constraintEqualToConstant:32]
    ]];
}

- (void)setupBottomControlBar {
    self.bottomControlBar = [[UIView alloc] init];
    self.bottomControlBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.65];
    self.bottomControlBar.layer.cornerRadius = 22;
    self.bottomControlBar.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    self.bottomControlBar.layer.borderWidth = 1.0;
    self.bottomControlBar.clipsToBounds = YES;
    self.bottomControlBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomControlBar];
    
    // 撤销按钮 (Undo)
    self.undoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [self.undoBtn setImage:[UIImage systemImageNamed:@"arrow.uturn.backward.circle.fill" withConfiguration:iconConfig] forState:UIControlStateNormal];
    [self.undoBtn setTitle:L(@" Undo", @" 撤销") forState:UIControlStateNormal];
    [self.undoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.undoBtn.tintColor = [UIColor whiteColor];
    self.undoBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.undoBtn addTarget:self action:@selector(undoLastStroke) forControlEvents:UIControlEventTouchUpInside];
    self.undoBtn.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 清除全部 (Clear)
    self.clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearBtn setImage:[UIImage systemImageNamed:@"trash.fill" withConfiguration:iconConfig] forState:UIControlStateNormal];
    [self.clearBtn setTitle:L(@" Clear", @" 清屏") forState:UIControlStateNormal];
    [self.clearBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    self.clearBtn.tintColor = [UIColor systemRedColor];
    self.clearBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.clearBtn addTarget:self action:@selector(clearCanvas) forControlEvents:UIControlEventTouchUpInside];
    self.clearBtn.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 上一页 (Prev Page)
    self.prevPageBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.prevPageBtn setImage:[UIImage systemImageNamed:@"chevron.left.circle.fill" withConfiguration:iconConfig] forState:UIControlStateNormal];
    [self.prevPageBtn setTitle:L(@" Prev", @" 上一页") forState:UIControlStateNormal];
    [self.prevPageBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.prevPageBtn.tintColor = [UIColor whiteColor];
    self.prevPageBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.prevPageBtn addTarget:self action:@selector(pagePrevious) forControlEvents:UIControlEventTouchUpInside];
    self.prevPageBtn.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 下一页 (Next Page)
    self.nextPageBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.nextPageBtn setImage:[UIImage systemImageNamed:@"chevron.right.circle.fill" withConfiguration:iconConfig] forState:UIControlStateNormal];
    [self.nextPageBtn setTitle:L(@" Next", @" 下一页") forState:UIControlStateNormal];
    [self.nextPageBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.nextPageBtn.tintColor = [UIColor whiteColor];
    self.nextPageBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.nextPageBtn addTarget:self action:@selector(pageNext) forControlEvents:UIControlEventTouchUpInside];
    self.nextPageBtn.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.prevPageBtn, self.undoBtn, self.clearBtn, self.nextPageBtn]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomControlBar addSubview:stack];
    
    [NSLayoutConstraint activateConstraints:@[
        // 画布约束：夹在顶部栏与底部栏之间
        [self.canvasView.topAnchor constraintEqualToAnchor:self.topToolBar.bottomAnchor constant:10],
        [self.canvasView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.canvasView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.canvasView.bottomAnchor constraintEqualToAnchor:self.bottomControlBar.topAnchor constant:-10],
        
        // 底部控制栏约束
        [self.bottomControlBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [self.bottomControlBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.bottomControlBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.bottomControlBar.heightAnchor constraintEqualToConstant:44],
        
        [stack.topAnchor constraintEqualToAnchor:self.bottomControlBar.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.bottomControlBar.leadingAnchor constant:6],
        [stack.trailingAnchor constraintEqualToAnchor:self.bottomControlBar.trailingAnchor constant:-6],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomControlBar.bottomAnchor]
    ]];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    self.widthSegment.selectedSegmentTintColor = palette.primaryColor;
    self.prevPageBtn.tintColor = palette.primaryColor;
    self.nextPageBtn.tintColor = palette.primaryColor;
    self.undoBtn.tintColor = palette.primaryColor;
}

#pragma mark - Palette & Tool Actions

- (void)colorSelected:(UIButton *)sender {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    self.isEraserMode = NO;
    self.eraserToggleBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    self.eraserToggleBtn.tintColor = [UIColor whiteColor];
    
    self.strokeColor = sender.backgroundColor;
    self.strokeColorKey = sender.accessibilityLabel ?: HSBRemoteDrawColorRed;
    
    for (UIButton *btn in self.colorButtons) {
        if (btn == sender) {
            btn.layer.borderColor = [UIColor whiteColor].CGColor;
            btn.layer.borderWidth = 3.0;
            [UIView animateWithDuration:0.2 animations:^{
                btn.transform = CGAffineTransformMakeScale(1.15, 1.15);
            }];
        } else {
            btn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
            btn.layer.borderWidth = 1.0;
            [UIView animateWithDuration:0.2 animations:^{
                btn.transform = CGAffineTransformIdentity;
            }];
        }
    }
}

- (void)widthSegmentChanged:(UISegmentedControl *)seg {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    switch (seg.selectedSegmentIndex) {
        case 0: self.strokeWidth = 2.0; break;
        case 1: self.strokeWidth = 4.0; break;
        case 2: self.strokeWidth = 8.0; break;
        case 3: self.strokeWidth = 14.0; break;
        default: self.strokeWidth = 4.0; break;
    }
}

- (void)toggleEraserMode {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    
    self.isEraserMode = !self.isEraserMode;
    if (self.isEraserMode) {
        self.eraserToggleBtn.backgroundColor = [UIColor systemOrangeColor];
        self.eraserToggleBtn.tintColor = [UIColor whiteColor];
        for (UIButton *btn in self.colorButtons) {
            btn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
            btn.layer.borderWidth = 1.0;
            btn.transform = CGAffineTransformIdentity;
        }
    } else {
        self.eraserToggleBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        self.eraserToggleBtn.tintColor = [UIColor whiteColor];
        // 恢复选中第一个颜色
        if (self.colorButtons.count > 0) {
            [self colorSelected:self.colorButtons.firstObject];
        }
    }
}

#pragma mark - Undo & Clear & Navigation Actions

- (void)undoLastStroke {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    
    if (self.undoStack.count > 0) {
        [self.undoStack removeLastObject];
        self.canvasView.image = self.undoStack.lastObject; // 恢复上一步，或者 nil
    } else {
        self.canvasView.image = nil;
    }
    
    if (self.canvasView.image == nil) {
        self.titleTipLabel.hidden = NO;
    }
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPdfDraw,
            HSBRemotePayloadKeyType: HSBRemoteDrawTypeUndo,
            HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
        });
    } else {
        [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPdfDraw,
            HSBRemotePayloadKeyType: HSBRemoteDrawTypeUndo,
            HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
        }];
    }
}

- (void)clearCanvas {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [fb impactOccurred];
    
    [self.undoStack removeAllObjects];
    self.canvasView.image = nil;
    self.titleTipLabel.hidden = NO;
    
    NSDictionary *payload = @{
        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPdfDraw,
        HSBRemotePayloadKeyType: HSBRemoteDrawTypeClear,
        HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
    };
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(payload);
    } else {
        [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    }
}

- (void)pagePrevious {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: HSBRemoteSimulateActionLeft});
    } else {
        [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionLeft];
    }
}

- (void)pageNext {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: HSBRemoteSimulateActionRight});
    } else {
        [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:HSBRemoteSimulateActionRight];
    }
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.canvasView];
    
    // 检查触摸点是否在画布范围内
    if (!CGRectContainsPoint(self.canvasView.bounds, point)) {
        return;
    }
    
    self.titleTipLabel.hidden = YES;
    self.lastPoint = point;
    
    // 记录笔画开始前的快照到 Undo 栈（限制最多 20 步）
    if (self.canvasView.image) {
        [self.undoStack addObject:self.canvasView.image];
    }
    if (self.undoStack.count > 20) {
        [self.undoStack removeObjectAtIndex:0];
    }
    
    [self sendDrawInfo:self.lastPoint type:HSBRemoteDrawTypeBegan];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.canvasView];
    
    if (!CGRectContainsPoint(self.canvasView.bounds, currentPoint)) {
        return;
    }
    
    // 本地绘图
    [self drawLineFrom:self.lastPoint to:currentPoint];
    
    // 同步到电视端
    [self sendDrawInfo:currentPoint type:HSBRemoteDrawTypeMoved];
    
    self.lastPoint = currentPoint;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.canvasView];
    
    [self drawLineFrom:self.lastPoint to:currentPoint];
    [self sendDrawInfo:currentPoint type:HSBRemoteDrawTypeEnded];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

- (void)drawLineFrom:(CGPoint)fromPoint to:(CGPoint)toPoint {
    CGSize size = self.canvasView.bounds.size;
    if (size.width <= 0 || size.height <= 0) return;
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [self.canvasView.image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    
    if (self.isEraserMode) {
        // 橡皮擦模式：清除通道
        CGContextSetLineWidth(context, self.strokeWidth * 2.5);
        CGContextSetBlendMode(context, kCGBlendModeClear);
    } else {
        // 普通画笔模式
        CGContextSetLineWidth(context, self.strokeWidth);
        CGContextSetStrokeColorWithColor(context, self.strokeColor.CGColor);
        CGContextSetBlendMode(context, kCGBlendModeNormal);
    }
    
    CGContextMoveToPoint(context, fromPoint.x, fromPoint.y);
    CGContextAddLineToPoint(context, toPoint.x, toPoint.y);
    CGContextStrokePath(context);
    
    self.canvasView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

- (void)sendDrawInfo:(CGPoint)point type:(NSString *)type {
    CGFloat canvasW = self.canvasView.bounds.size.width;
    CGFloat canvasH = self.canvasView.bounds.size.height;
    if (canvasW <= 0 || canvasH <= 0) return;
    
    // 归一化相对坐标 (0.0 - 1.0)
    CGFloat relX = point.x / canvasW;
    CGFloat relY = point.y / canvasH;
    
    NSString *colorStr = self.isEraserMode ? HSBRemoteDrawTypeEraser : (self.strokeColorKey ?: HSBRemoteDrawColorRed);
    CGFloat currentWidth = self.isEraserMode ? (self.strokeWidth * 2.5) : self.strokeWidth;
    
    NSDictionary *payload = @{
        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPdfDraw,
        HSBRemotePayloadKeyType: type ?: HSBRemoteDrawTypeMoved,
        HSBRemotePayloadKeyX: @(relX),
        HSBRemotePayloadKeyY: @(relY),
        HSBRemotePayloadKeyColor: colorStr,
        HSBRemotePayloadKeyWidth: @(currentWidth),
        HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
    };
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(payload);
    } else {
        [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    }
}

@end
