//
//  PDFControlViewController.m
//  HSBWatchCompanion
//

#import "PDFControlViewController.h"
#import "HSBTVOSConnectionManager.h"
#import "HSBThemeManager.h"
#import "HSBPDFCanvasView.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface PDFControlViewController ()

// 绘制画布组件
@property (nonatomic, strong) HSBPDFCanvasView *canvasView;

// UI 组件
@property (nonatomic, strong) UIView *topToolBar;
@property (nonatomic, strong) NSMutableArray<UIButton *> *colorButtons;
@property (nonatomic, strong) UISegmentedControl *widthSegment;
@property (nonatomic, strong) UIButton *eraserToggleBtn;
@property (nonatomic, strong) UIButton *undoBtn;
@property (nonatomic, strong) UIButton *clearBtn;

// 底部翻页控制栏
@property (nonatomic, strong) UIView *bottomControlBar;
@property (nonatomic, strong) UIButton *prevPageBtn;
@property (nonatomic, strong) UIButton *nextPageBtn;

@end

@implementation PDFControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.colorButtons = [NSMutableArray array];
    self.view.backgroundColor = [UIColor clearColor];
    
    [self setupTopToolBar];
    [self setupBottomControlBar];
    [self setupCanvas];
    [self applyThemeStyle];
}

#pragma mark - UI Setup

- (void)setupCanvas {
    self.canvasView = [[HSBPDFCanvasView alloc] initWithFrame:CGRectZero];
    self.canvasView.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) weakSelf = self;
    self.canvasView.onDrawEvent = ^(CGPoint point, NSString *drawType, NSString *colorKey, CGFloat width) {
        [weakSelf sendDrawInfo:point drawType:drawType colorKey:colorKey width:width];
    };
    [self.view addSubview:self.canvasView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.canvasView.topAnchor constraintEqualToAnchor:self.topToolBar.bottomAnchor constant:10],
        [self.canvasView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.canvasView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.canvasView.bottomAnchor constraintEqualToAnchor:self.bottomControlBar.topAnchor constant:-10]
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
    
    NSArray *colorPalette = @[
        @{@"color": [UIColor systemRedColor], @"key": HSBRemoteDrawColorRed},
        @{@"color": [UIColor systemBlueColor], @"key": HSBRemoteDrawColorBlue},
        @{@"color": [UIColor systemGreenColor], @"key": HSBRemoteDrawColorGreen},
        @{@"color": [UIColor systemYellowColor], @"key": HSBRemoteDrawColorYellow},
        @{@"color": [UIColor whiteColor], @"key": HSBRemoteDrawColorWhite},
        @{@"color": [UIColor colorWithWhite:0.25 alpha:1.0], @"key": HSBRemoteDrawColorBlack}
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
    
    self.widthSegment = [[UISegmentedControl alloc] initWithItems:@[@"2pt", @"4pt", @"8pt", @"14pt"]];
    self.widthSegment.selectedSegmentIndex = 1;
    [self.widthSegment addTarget:self action:@selector(widthSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.widthSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.topToolBar addSubview:self.widthSegment];
    
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
    
    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    
    self.undoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.undoBtn setImage:[UIImage systemImageNamed:@"arrow.uturn.backward.circle.fill" withConfiguration:iconConfig] forState:UIControlStateNormal];
    [self.undoBtn setTitle:L(@" Undo", @" 撤销") forState:UIControlStateNormal];
    [self.undoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.undoBtn.tintColor = [UIColor whiteColor];
    self.undoBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.undoBtn addTarget:self action:@selector(undoLastStroke) forControlEvents:UIControlEventTouchUpInside];
    
    self.clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearBtn setImage:[UIImage systemImageNamed:@"trash.fill" withConfiguration:iconConfig] forState:UIControlStateNormal];
    [self.clearBtn setTitle:L(@" Clear", @" 清屏") forState:UIControlStateNormal];
    [self.clearBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    self.clearBtn.tintColor = [UIColor systemRedColor];
    self.clearBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.clearBtn addTarget:self action:@selector(clearCanvas) forControlEvents:UIControlEventTouchUpInside];
    
    self.prevPageBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.prevPageBtn setImage:[UIImage systemImageNamed:@"chevron.left.circle.fill" withConfiguration:iconConfig] forState:UIControlStateNormal];
    [self.prevPageBtn setTitle:L(@" Prev", @" 上一页") forState:UIControlStateNormal];
    [self.prevPageBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.prevPageBtn.tintColor = [UIColor whiteColor];
    self.prevPageBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.prevPageBtn addTarget:self action:@selector(pagePrevious) forControlEvents:UIControlEventTouchUpInside];
    
    self.nextPageBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.nextPageBtn setImage:[UIImage systemImageNamed:@"chevron.right.circle.fill" withConfiguration:iconConfig] forState:UIControlStateNormal];
    [self.nextPageBtn setTitle:L(@" Next", @" 下一页") forState:UIControlStateNormal];
    [self.nextPageBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.nextPageBtn.tintColor = [UIColor whiteColor];
    self.nextPageBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.nextPageBtn addTarget:self action:@selector(pageNext) forControlEvents:UIControlEventTouchUpInside];
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.prevPageBtn, self.undoBtn, self.clearBtn, self.nextPageBtn]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomControlBar addSubview:stack];
    
    [NSLayoutConstraint activateConstraints:@[
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
    
    self.canvasView.isEraserMode = NO;
    self.eraserToggleBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    self.eraserToggleBtn.tintColor = [UIColor whiteColor];
    
    self.canvasView.strokeColor = sender.backgroundColor;
    self.canvasView.strokeColorKey = sender.accessibilityLabel ?: HSBRemoteDrawColorRed;
    
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
        case 0: self.canvasView.strokeWidth = 2.0; break;
        case 1: self.canvasView.strokeWidth = 4.0; break;
        case 2: self.canvasView.strokeWidth = 8.0; break;
        case 3: self.canvasView.strokeWidth = 14.0; break;
        default: self.canvasView.strokeWidth = 4.0; break;
    }
}

- (void)toggleEraserMode {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    
    self.canvasView.isEraserMode = !self.canvasView.isEraserMode;
    if (self.canvasView.isEraserMode) {
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
        if (self.colorButtons.count > 0) {
            [self colorSelected:self.colorButtons.firstObject];
        }
    }
}

#pragma mark - Undo, Clear & Navigation

- (void)undoLastStroke {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    [self.canvasView undoLastStroke];
    
    NSDictionary *payload = @{
        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPdfDraw,
        HSBRemotePayloadKeyType: HSBRemoteDrawTypeUndo,
        HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
    };
    [self dispatchPayload:payload];
}

- (void)clearCanvas {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [fb impactOccurred];
    [self.canvasView clearCanvas];
    
    NSDictionary *payload = @{
        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPdfDraw,
        HSBRemotePayloadKeyType: HSBRemoteDrawTypeClear,
        HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
    };
    [self dispatchPayload:payload];
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

- (void)sendDrawInfo:(CGPoint)point drawType:(NSString *)type colorKey:(NSString *)colorKey width:(CGFloat)width {
    CGFloat canvasW = self.canvasView.bounds.size.width;
    CGFloat canvasH = self.canvasView.bounds.size.height;
    if (canvasW <= 0 || canvasH <= 0) return;
    
    CGFloat relX = point.x / canvasW;
    CGFloat relY = point.y / canvasH;
    
    NSDictionary *payload = @{
        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPdfDraw,
        HSBRemotePayloadKeyType: type ?: HSBRemoteDrawTypeMoved,
        HSBRemotePayloadKeyX: @(relX),
        HSBRemotePayloadKeyY: @(relY),
        HSBRemotePayloadKeyColor: colorKey,
        HSBRemotePayloadKeyWidth: @(width),
        HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
    };
    [self dispatchPayload:payload];
}

- (void)dispatchPayload:(NSDictionary *)payload {
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(payload);
    } else {
        [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    }
}

@end
