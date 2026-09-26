#import "OFButtonWindow.h"
#import "OFPrefs.h"
#import <AudioToolbox/AudioToolbox.h>

@interface OFButtonWindow ()
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) NSTimer *autoDismissTimer;
@property (nonatomic, copy) void (^currentTapHandler)(void);
@end

@implementation OFButtonWindow

+ (instancetype)sharedWindow {
    static OFButtonWindow *window = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIScreen *mainScreen = [UIScreen mainScreen];
        window = [[OFButtonWindow alloc] initWithFrame:mainScreen.bounds];
        window.windowLevel = UIWindowLevelAlert + 100.0;
        window.backgroundColor = [UIColor clearColor];
        window.userInteractionEnabled = YES;
        window.hidden = YES;
        
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.userInteractionEnabled = YES;
        window.rootViewController = rootVC;
        
        [window setupButton];
    });
    return window;
}

- (void)setupButton {
    self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.actionButton.frame = CGRectMake(0, 0, 52, 52);
    self.actionButton.layer.cornerRadius = 26;
    self.actionButton.clipsToBounds = YES;
    self.actionButton.alpha = 0.0;
    
    // Smooth modern blur effect
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.frame = self.actionButton.bounds;
    self.blurView.userInteractionEnabled = NO;
    self.blurView.layer.cornerRadius = 26;
    self.blurView.clipsToBounds = YES;
    [self.actionButton addSubview:self.blurView];
    
    // Subtle border glow
    self.actionButton.layer.borderWidth = 0.8;
    self.actionButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    
    // SF Symbol Rotate Icon
    UIImageConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
    UIImage *img = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath" withConfiguration:config];
    if (!img) {
        img = [UIImage systemImageNamed:@"rotate.right" withConfiguration:config];
    }
    
    self.iconImageView = [[UIImageView alloc] initWithImage:img];
    self.iconImageView.tintColor = [UIColor labelColor];
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconImageView.frame = CGRectMake(11, 11, 30, 30);
    self.iconImageView.userInteractionEnabled = NO;
    [self.actionButton addSubview:self.iconImageView];
    
    [self.actionButton addTarget:self action:@selector(handleButtonTap) forControlEvents:UIControlEventTouchUpInside];
    [self.rootViewController.view addSubview:self.actionButton];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.actionButton.alpha < 0.05) {
        return nil;
    }
    CGPoint btnPoint = [self.actionButton convertPoint:point fromView:self];
    if ([self.actionButton pointInside:btnPoint withEvent:event]) {
        return [self.actionButton hitTest:btnPoint withEvent:event];
    }
    return nil; // Pass touches through to apps behind
}

- (void)updateButtonPosition {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat width = screenBounds.size.width;
    CGFloat height = screenBounds.size.height;
    CGFloat margin = 20.0;
    CGFloat btnSize = 52.0;
    
    // Safe area bottom inset if available
    CGFloat bottomInset = 34.0;
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets insets = [UIApplication sharedApplication].windows.firstObject.safeAreaInsets;
        if (insets.bottom > 0) bottomInset = insets.bottom;
    }
    
    NSInteger pos = [OFPrefs sharedInstance].position;
    CGPoint center;
    switch (pos) {
        case 1: // Bottom Left
            center = CGPointMake(margin + btnSize / 2.0, height - bottomInset - btnSize / 2.0 - 10);
            break;
        case 2: // Top Right
            center = CGPointMake(width - margin - btnSize / 2.0, 60 + btnSize / 2.0);
            break;
        case 0: // Bottom Right (Default)
        default:
            center = CGPointMake(width - margin - btnSize / 2.0, height - bottomInset - btnSize / 2.0 - 10);
            break;
    }
    
    self.actionButton.center = center;
}

- (void)showPromptWithOrientation:(UIInterfaceOrientation)orientation tapHandler:(void (^)(void))tapHandler {
    self.currentTapHandler = tapHandler;
    [self.autoDismissTimer invalidate];
    
    [self updateButtonPosition];
    self.hidden = NO;
    
    if ([OFPrefs sharedInstance].hapticFeedback) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback prepare];
        [feedback impactOccurred];
    }
    
    // Animated entry
    self.actionButton.transform = CGAffineTransformMakeScale(0.3, 0.3);
    self.actionButton.alpha = 0.0;
    
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.65 initialSpringVelocity:0.6 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.actionButton.alpha = 1.0;
        self.actionButton.transform = CGAffineTransformIdentity;
    } completion:nil];
    
    // Auto dismiss timer
    CGFloat dur = [OFPrefs sharedInstance].duration;
    self.autoDismissTimer = [NSTimer scheduledTimerWithTimeInterval:dur repeats:NO block:^(NSTimer * _Nonnull timer) {
        [self hidePrompt];
    }];
}

- (void)handleButtonTap {
    if ([OFPrefs sharedInstance].hapticFeedback) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback prepare];
        [feedback impactOccurred];
    }
    
    // Tap animation
    [UIView animateWithDuration:0.1 animations:^{
        self.actionButton.transform = CGAffineTransformMakeScale(0.85, 0.85);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 animations:^{
            self.actionButton.transform = CGAffineTransformIdentity;
        }];
    }];
    
    if (self.currentTapHandler) {
        self.currentTapHandler();
    }
    [self hidePrompt];
}

- (void)hidePrompt {
    [self.autoDismissTimer invalidate];
    self.autoDismissTimer = nil;
    self.currentTapHandler = nil;
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.actionButton.alpha = 0.0;
        self.actionButton.transform = CGAffineTransformMakeScale(0.5, 0.5);
    } completion:^(BOOL finished) {
        if (self.actionButton.alpha <= 0.05) {
            self.hidden = YES;
        }
    }];
}

@end
