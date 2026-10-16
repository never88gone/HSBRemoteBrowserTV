//
//  HSBLocalLLMModelCell.m
//  HSBWatchCompanion
//

#import "HSBLocalLLMModelCell.h"

@implementation HSBLocalLLMModelCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
        self.progressView.hidden = YES;
        [self.contentView addSubview:self.progressView];
        
        self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.actionButton.layer.cornerRadius = 8;
        
        self.testButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.testButton.layer.cornerRadius = 8;
        [self.testButton setTitle:@"测试" forState:UIControlStateNormal];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.actionButton.heightAnchor constraintEqualToConstant:32],
            [self.actionButton.widthAnchor constraintEqualToConstant:60],
            [self.testButton.heightAnchor constraintEqualToConstant:32],
            [self.testButton.widthAnchor constraintEqualToConstant:60]
        ]];
        
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.actionButton, self.testButton]];
        stack.axis = UILayoutConstraintAxisHorizontal;
        stack.spacing = 10;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:stack];
        
        [NSLayoutConstraint activateConstraints:@[
            [stack.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-15],
            
            [self.progressView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
            [self.progressView.trailingAnchor constraintEqualToAnchor:stack.leadingAnchor constant:-10],
            [self.progressView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5]
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 计算右侧按钮所占用的宽度
    CGFloat rightMargin = 15;
    if (!self.testButton.hidden) {
        rightMargin += 60 + 10 + 60;
    } else {
        rightMargin += 60;
    }
    
    // 限制系统原生 label 的最大宽度，防止铺在按钮下方
    CGFloat maxLabelWidth = self.contentView.bounds.size.width - rightMargin - 20;
    
    CGRect textFrame = self.textLabel.frame;
    if (textFrame.size.width > maxLabelWidth) {
        textFrame.size.width = maxLabelWidth;
        self.textLabel.frame = textFrame;
    }
    
    CGRect detailFrame = self.detailTextLabel.frame;
    if (detailFrame.size.width > maxLabelWidth) {
        detailFrame.size.width = maxLabelWidth;
        self.detailTextLabel.frame = detailFrame;
    }
}

@end
