#import "OFButtonWindow.h"
#import "OFPrefs.h"
#import <AudioToolbox/AudioToolbox.h>

@interface OFTouchPassthroughRootViewController : UIViewController
@end

@implementation OFTouchPassthroughRootViewController
- (BOOL)shouldAutorotate {
    return YES;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
- (BOOL)prefersStatusBarHidden {
    return NO;
}
- (BOOL)prefersHomeIndicatorAutoHidden {
    return NO;
}
@end

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
        @try {
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            UIWindowScene *activeScene = nil;
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                        activeScene = (UIWindowScene *)scene;
                        break;
                    }
                }
            }
            
            if (@available(iOS 13.0, *)) {
                if (activeScene) {
                    window = [[OFButtonWindow alloc] initWithWindowScene:activeScene];
                }
            }
            if (!window) {
                window = [[OFButtonWindow alloc] initWithFrame:screenBounds];
            }
            
            window.windowLevel = UIWindowLevelStatusBar + 50.0;
            window.backgroundColor = [UIColor clearColor];
            window.opaque = NO;
            window.userInteractionEnabled = YES;
            
            OFTouchPassthroughRootViewController *rootVC = [[OFTouchPassthroughRootViewController alloc] init];
            rootVC.view.backgroundColor = [UIColor clearColor];
            rootVC.view.userInteractionEnabled = YES;
            window.rootViewController = rootVC;
            
            // Critical: Keep hidden initially, do not become key window
            window.hidden = YES;
            
            [window setupButton];
        } @catch (NSException *e) {
            NSLog(@"[OrientFlow] Exception in sharedWindow init: %@", e);
        }
    });
    return window;
}

- (void)setupButton {
    @try {
        self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.actionButton.frame = CGRectMake(0, 0, 52, 52);
        self.actionButton.layer.cornerRadius = 26;
        self.actionButton.clipsToBounds = YES;
        self.actionButton.alpha = 0.0;
        
        // Modern Frosted Blur
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        self.blurView.frame = self.actionButton.bounds;
        self.blurView.userInteractionEnabled = NO;
        self.blurView.layer.cornerRadius = 26;
        self.blurView.clipsToBounds = YES;
        [self.actionButton addSubview:self.blurView];
        
        // Border glow
        self.actionButton.layer.borderWidth = 1.0;
        self.actionButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
        
        // Smooth shadow
        self.actionButton.layer.shadowColor = [UIColor blackColor].CGColor;
        self.actionButton.layer.shadowOffset = CGSizeMake(0, 4);
        self.actionButton.layer.shadowRadius = 8;
        self.actionButton.layer.shadowOpacity = 0.35;
        
        // SF Symbol icon
        UIImageConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
        UIImage *img = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath" withConfiguration:config];
        if (!img) {
            img = [UIImage systemImageNamed:@"rotate.right" withConfiguration:config];
        }
        
        self.iconImageView = [[UIImageView alloc] initWithImage:img];
        self.iconImageView.tintColor = [UIColor whiteColor];
        self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
        self.iconImageView.frame = CGRectMake(11, 11, 30, 30);
        self.iconImageView.userInteractionEnabled = NO;
        [self.actionButton addSubview:self.iconImageView];
        
        [self.actionButton addTarget:self action:@selector(handleButtonTap) forControlEvents:UIControlEventTouchUpInside];
        [self.rootViewController.view addSubview:self.actionButton];
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in setupButton: %@", e);
    }
}

- (BOOL)_canBecomeKeyWindow {
    return NO;
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)_canAffectStatusBarAppearance {
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.actionButton.alpha < 0.05) {
        return nil;
    }
    CGPoint btnPoint = [self.actionButton convertPoint:point fromView:self];
    if ([self.actionButton pointInside:btnPoint withEvent:event]) {
        return self.actionButton;
    }
    return nil; // Forward all other touches to background apps!
}

- (void)updateButtonPosition {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat width = screenBounds.size.width;
    CGFloat height = screenBounds.size.height;
    CGFloat margin = 20.0;
    CGFloat btnSize = 52.0;
    
    CGFloat bottomInset = 34.0;
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets insets = [UIApplication sharedApplication].windows.firstObject.safeAreaInsets;
        if (insets.bottom > 0) bottomInset = insets.bottom;
    }
    
    OFPrefs *prefs = [OFPrefs sharedInstance];
    NSInteger pos = prefs.position;
    CGPoint center;
    switch (pos) {
        case 1: // Bottom Left
            center = CGPointMake(margin + btnSize / 2.0, height - bottomInset - btnSize / 2.0 - 10);
            break;
        case 2: // Top Right
            center = CGPointMake(width - margin - btnSize / 2.0, 60 + btnSize / 2.0);
            break;
        case 3: { // Custom (Sliders: % of width & % of height)
            CGFloat pctX = prefs.offsetX / 100.0;
            CGFloat pctY = prefs.offsetY / 100.0;
            CGFloat half = btnSize / 2.0;
            CGFloat cx = pctX * width;
            CGFloat cy = pctY * height;
            // Clamping so button remains on screen
            cx = MAX(half + 8.0, MIN(width - half - 8.0, cx));
            cy = MAX(half + 20.0, MIN(height - half - 20.0, cy));
            center = CGPointMake(cx, cy);
            break;
        }
        case 0: // Bottom Right (Default)
        default:
            center = CGPointMake(width - margin - btnSize / 2.0, height - bottomInset - btnSize / 2.0 - 10);
            break;
    }
    
    self.actionButton.center = center;
}

- (void)showPromptWithOrientation:(UIInterfaceOrientation)orientation tapHandler:(void (^)(void))tapHandler {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showPromptWithOrientation:orientation tapHandler:tapHandler];
        });
        return;
    }
    
    @try {
        self.currentTapHandler = tapHandler;
        [self.autoDismissTimer invalidate];
        self.autoDismissTimer = nil;
        
        // Safely update windowScene only if nil or disconnected to avoid iOS 16 assertion crash
        if (@available(iOS 13.0, *)) {
            if (!self.windowScene || self.windowScene.activationState != UISceneActivationStateForegroundActive) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                        @try {
                            self.windowScene = (UIWindowScene *)scene;
                        } @catch (NSException *scEx) {
                            NSLog(@"[OrientFlow] Exception setting windowScene: %@", scEx);
                        }
                        break;
                    }
                }
            }
        }
        
        [self updateButtonPosition];
        self.hidden = NO;
        
        if ([OFPrefs sharedInstance].hapticFeedback) {
            @try {
                UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                [feedback prepare];
                [feedback impactOccurred];
            } @catch (NSException *hEx) {}
        }
        
        self.actionButton.transform = CGAffineTransformMakeScale(0.3, 0.3);
        self.actionButton.alpha = 0.0;
        
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.68 initialSpringVelocity:0.5 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            self.actionButton.alpha = 1.0;
            self.actionButton.transform = CGAffineTransformIdentity;
        } completion:nil];
        
        CGFloat dur = [OFPrefs sharedInstance].duration;
        self.autoDismissTimer = [NSTimer scheduledTimerWithTimeInterval:dur repeats:NO block:^(NSTimer * _Nonnull timer) {
            [self hidePrompt];
        }];
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in showPromptWithOrientation: %@", e);
    }
}

- (void)handleButtonTap {
    @try {
        if ([OFPrefs sharedInstance].hapticFeedback) {
            @try {
                UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [feedback prepare];
                [feedback impactOccurred];
            } @catch (NSException *hEx) {}
        }
        
        [UIView animateWithDuration:0.1 animations:^{
            self.actionButton.transform = CGAffineTransformMakeScale(0.85, 0.85);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.15 animations:^{
                self.actionButton.transform = CGAffineTransformIdentity;
            }];
        }];
        
        void (^handler)(void) = self.currentTapHandler;
        [self hidePrompt];
        
        if (handler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {
                    handler();
                } @catch (NSException *tapEx) {
                    NSLog(@"[OrientFlow] Exception in tap handler: %@", tapEx);
                }
            });
        }
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in handleButtonTap: %@", e);
    }
}

- (void)hidePrompt {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hidePrompt];
        });
        return;
    }
    
    @try {
        [self.autoDismissTimer invalidate];
        self.autoDismissTimer = nil;
        self.currentTapHandler = nil;
        
        [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.actionButton.alpha = 0.0;
            self.actionButton.transform = CGAffineTransformMakeScale(0.5, 0.5);
        } completion:^(BOOL finished) {
            if (self.actionButton.alpha <= 0.05) {
                self.hidden = YES;
            }
        }];
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in hidePrompt: %@", e);
    }
}

- (BOOL)isPromptShowing {
    return !self.hidden && self.actionButton.alpha > 0.1;
}

@end
