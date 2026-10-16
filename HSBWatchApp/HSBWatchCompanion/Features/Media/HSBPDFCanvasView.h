//
//  HSBPDFCanvasView.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBPDFCanvasView : UIView

@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, copy) NSString *strokeColorKey;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) BOOL isEraserMode;

@property (nonatomic, copy, nullable) void (^onDrawEvent)(CGPoint point, NSString *drawType, NSString *colorKey, CGFloat width);

- (void)undoLastStroke;
- (void)clearCanvas;

@end

NS_ASSUME_NONNULL_END
