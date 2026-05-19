//
//  PDFControlViewController.m
//  HSBWatchCompanion
//

#import "PDFControlViewController.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface PDFControlViewController ()
@property (nonatomic, strong) UIImageView *canvasView;
@property (nonatomic, assign) CGPoint lastPoint;
@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, assign) CGFloat strokeWidth;

// 主题联动组件
@property (nonatomic, strong) UILabel *instructionLabel;
@property (nonatomic, strong) UIButton *clearBtn;
@end

@implementation PDFControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.strokeColor = [UIColor redColor];
    self.strokeWidth = 3.0;
    
    // Canvas
    self.canvasView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.canvasView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.canvasView.userInteractionEnabled = YES;
    self.canvasView.backgroundColor = [UIColor blackColor]; // PDF content area background
    [self.view addSubview:self.canvasView];
    
    // Title/Instruction
    self.instructionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, self.view.bounds.size.width, 30)];
    self.instructionLabel.text = L(@"PDF Annotation (Draw to Sync to TV)", @"PDF 批注 (手绘实时同步电视)");
    self.instructionLabel.textAlignment = NSTextAlignmentCenter;
    self.instructionLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.view addSubview:self.instructionLabel];
    
    // Clear Button
    self.clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearBtn setTitle:L(@"Clear All", @"清除画布") forState:UIControlStateNormal];
    [self.clearBtn setFrame:CGRectMake(16, 10, 80, 30)];
    [self.clearBtn addTarget:self action:@selector(clearCanvas) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.clearBtn];
    
    [self applyThemeStyle];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    if (self.clearBtn) {
        self.clearBtn.tintColor = palette.primaryColor;
    }
    
    if (self.instructionLabel) {
        self.instructionLabel.textColor = [palette.primaryColor colorWithAlphaComponent:0.8];
    }
    
    if (self.canvasView) {
        self.canvasView.backgroundColor = [UIColor blackColor];
    }
}

- (void)clearCanvas {
    self.canvasView.image = nil;
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{@"action": @"pdf_draw", @"type": @"clear"});
    }
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    self.lastPoint = [touch locationInView:self.canvasView];
    
    [self sendDrawInfo:self.lastPoint type:@"began"];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.canvasView];
    
    // Local Draw
    [self drawLineFrom:self.lastPoint to:currentPoint];
    
    // Sync to TV
    [self sendDrawInfo:currentPoint type:@"moved"];
    
    self.lastPoint = currentPoint;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.canvasView];
    
    [self drawLineFrom:self.lastPoint to:currentPoint];
    [self sendDrawInfo:currentPoint type:@"ended"];
}

- (void)drawLineFrom:(CGPoint)fromPoint to:(CGPoint)toPoint {
    UIGraphicsBeginImageContext(self.canvasView.frame.size);
    [self.canvasView.image drawInRect:CGRectMake(0, 0, self.canvasView.frame.size.width, self.canvasView.frame.size.height)];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextMoveToPoint(context, fromPoint.x, fromPoint.y);
    CGContextAddLineToPoint(context, toPoint.x, toPoint.y);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineWidth(context, self.strokeWidth);
    CGContextSetStrokeColorWithColor(context, self.strokeColor.CGColor);
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    
    CGContextStrokePath(context);
    
    self.canvasView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

- (void)sendDrawInfo:(CGPoint)point type:(NSString *)type {
    if (!self.sendPayloadBlock) return;
    
    // Send relative coordinates (0.0 - 1.0) to match TV screen
    CGFloat relX = point.x / self.canvasView.bounds.size.width;
    CGFloat relY = point.y / self.canvasView.bounds.size.height;
    
    NSDictionary *payload = @{
        @"action": @"pdf_draw",
        @"type": type,
        @"x": @(relX),
        @"y": @(relY),
        @"color": @"red", // Hardcoded for now
        @"width": @(self.strokeWidth)
    };
    
    self.sendPayloadBlock(payload);
}

@end
