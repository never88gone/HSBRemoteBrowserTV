//
//  HSBPDFCanvasView.m
//  HSBWatchCompanion
//

#import "HSBPDFCanvasView.h"
#import "HSBTVOSConnectionManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBPDFCanvasView ()
@property (nonatomic, strong) UIImageView *canvasImageView;
@property (nonatomic, strong) UILabel *titleTipLabel;
@property (nonatomic, assign) CGPoint lastPoint;
@property (nonatomic, strong) NSMutableArray<UIImage *> *undoStack;
@end

@implementation HSBPDFCanvasView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.undoStack = [NSMutableArray array];
    self.strokeColor = [UIColor systemRedColor];
    self.strokeColorKey = HSBRemoteDrawColorRed;
    self.strokeWidth = 4.0;
    self.isEraserMode = NO;
    
    self.backgroundColor = [UIColor blackColor];
    self.layer.cornerRadius = 16;
    self.layer.masksToBounds = YES;
    self.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor;
    self.layer.borderWidth = 1.0;
    self.userInteractionEnabled = YES;
    
    self.canvasImageView = [[UIImageView alloc] initWithFrame:self.bounds];
    self.canvasImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.canvasImageView.userInteractionEnabled = NO;
    [self addSubview:self.canvasImageView];
    
    self.titleTipLabel = [[UILabel alloc] init];
    self.titleTipLabel.text = L(@"✏️ Draw / Annotate (Syncing to TV in Real-time)", @"✏️ 屏幕手绘批注 (实时无缝同步至电视)");
    self.titleTipLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35];
    self.titleTipLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.titleTipLabel.textAlignment = NSTextAlignmentCenter;
    self.titleTipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.titleTipLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleTipLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.titleTipLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
    ]];
}

- (void)undoLastStroke {
    if (self.undoStack.count > 0) {
        [self.undoStack removeLastObject];
        self.canvasImageView.image = self.undoStack.lastObject;
    } else {
        self.canvasImageView.image = nil;
    }
    if (self.canvasImageView.image == nil) {
        self.titleTipLabel.hidden = NO;
    }
}

- (void)clearCanvas {
    [self.undoStack removeAllObjects];
    self.canvasImageView.image = nil;
    self.titleTipLabel.hidden = NO;
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    if (!CGRectContainsPoint(self.bounds, point)) return;
    
    self.titleTipLabel.hidden = YES;
    self.lastPoint = point;
    
    if (self.canvasImageView.image) {
        [self.undoStack addObject:self.canvasImageView.image];
    }
    if (self.undoStack.count > 20) {
        [self.undoStack removeObjectAtIndex:0];
    }
    
    [self notifyDrawEvent:self.lastPoint drawType:HSBRemoteDrawTypeBegan];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self];
    if (!CGRectContainsPoint(self.bounds, currentPoint)) return;
    
    [self drawLineFrom:self.lastPoint to:currentPoint];
    [self notifyDrawEvent:currentPoint drawType:HSBRemoteDrawTypeMoved];
    self.lastPoint = currentPoint;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self];
    [self drawLineFrom:self.lastPoint to:currentPoint];
    [self notifyDrawEvent:currentPoint drawType:HSBRemoteDrawTypeEnded];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

- (void)drawLineFrom:(CGPoint)fromPoint to:(CGPoint)toPoint {
    CGSize size = self.bounds.size;
    if (size.width <= 0 || size.height <= 0) return;
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [self.canvasImageView.image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    
    if (self.isEraserMode) {
        CGContextSetLineWidth(context, self.strokeWidth * 2.5);
        CGContextSetBlendMode(context, kCGBlendModeClear);
    } else {
        CGContextSetLineWidth(context, self.strokeWidth);
        CGContextSetStrokeColorWithColor(context, self.strokeColor.CGColor);
        CGContextSetBlendMode(context, kCGBlendModeNormal);
    }
    
    CGContextMoveToPoint(context, fromPoint.x, fromPoint.y);
    CGContextAddLineToPoint(context, toPoint.x, toPoint.y);
    CGContextStrokePath(context);
    
    self.canvasImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

- (void)notifyDrawEvent:(CGPoint)point drawType:(NSString *)type {
    if (self.onDrawEvent) {
        NSString *colorStr = self.isEraserMode ? HSBRemoteDrawTypeEraser : (self.strokeColorKey ?: HSBRemoteDrawColorRed);
        CGFloat currentWidth = self.isEraserMode ? (self.strokeWidth * 2.5) : self.strokeWidth;
        self.onDrawEvent(point, type, colorStr, currentWidth);
    }
}

@end
