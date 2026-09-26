#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import "OFPrefs.h"
#import "OFButtonWindow.h"

@interface SBOrientationLockManager : NSObject
+ (id)sharedInstance;
- (BOOL)isUserLocked;
- (void)lock:(UIInterfaceOrientation)orientation;
- (void)unlock;
- (UIInterfaceOrientation)userLockOrientation;
- (BOOL)lockOverrideEnabled;
- (void)setLockOverrideEnabled:(BOOL)enabled forReason:(id)reason;
@end

@interface SpringBoard : UIApplication
@end

static CMMotionManager *motionMgr = nil;
static UIInterfaceOrientation candidateOrientation = UIInterfaceOrientationUnknown;
static NSTimeInterval lastTriggerTime = 0;
static BOOL tempUnlockedForSession = NO;

static void ReloadPrefsCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[OFPrefs sharedInstance] loadSettings];
}

static void CheckMotionAndSuggest(CMDeviceMotion *motion) {
    OFPrefs *prefs = [OFPrefs sharedInstance];
    if (!prefs.enabled) return;
    
    SBOrientationLockManager *lockMgr = [%c(SBOrientationLockManager) sharedInstance];
    if (![lockMgr isUserLocked] && !tempUnlockedForSession) {
        return;
    }
    
    double gx = motion.gravity.x;
    double gy = motion.gravity.y;
    double gz = motion.gravity.z;
    
    // Ignore if device is lying flat on a desk
    if (fabs(gz) > 0.85) {
        return;
    }
    
    UIInterfaceOrientation target = UIInterfaceOrientationUnknown;
    
    // Landscape check: horizontal acceleration dominant
    if (fabs(gx) > 0.70 && fabs(gy) < 0.45) {
        if (gx > 0.70) {
            target = UIInterfaceOrientationLandscapeLeft;
        } else if (gx < -0.70) {
            target = UIInterfaceOrientationLandscapeRight;
        }
    } else if (gy < -0.75 && fabs(gx) < 0.40) {
        // Returned to Portrait
        if (tempUnlockedForSession && prefs.autoRelockOnPortrait) {
            // Re-lock when returning to portrait upright
            tempUnlockedForSession = NO;
            [lockMgr lock:UIInterfaceOrientationPortrait];
        }
        return;
    }
    
    if (target == UIInterfaceOrientationUnknown) {
        return;
    }
    
    UIInterfaceOrientation currentLocked = [lockMgr userLockOrientation];
    if (target == currentLocked && [lockMgr isUserLocked]) {
        return; // Already matches locked orientation
    }
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - lastTriggerTime < 1.8) {
        return; // Prevent debounce spam
    }
    
    candidateOrientation = target;
    lastTriggerTime = now;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[OFButtonWindow sharedWindow] showPromptWithOrientation:target tapHandler:^{
            // Khi bấm mở xoay: Mở khoá xoay để màn hình tự xoay theo hướng máy
            SBOrientationLockManager *mgr = [%c(SBOrientationLockManager) sharedInstance];
            if ([mgr isUserLocked]) {
                tempUnlockedForSession = YES;
                [mgr unlock];
            }
        }];
    });
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    [[OFPrefs sharedInstance] loadSettings];
    
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        ReloadPrefsCallback,
        CFSTR(kOrientFlowPrefsNotification),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    
    // Low frequency updates (8Hz) -> consumes ~0% CPU, saving battery completely
    motionMgr = [[CMMotionManager alloc] init];
    motionMgr.deviceMotionUpdateInterval = 0.125;
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.name = @"com.jinken.orientflow.motionQueue";
    queue.qualityOfService = NSQualityOfServiceUtility;
    
    if (motionMgr.isDeviceMotionAvailable) {
        [motionMgr startDeviceMotionUpdatesToQueue:queue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            if (motion && !error) {
                CheckMotionAndSuggest(motion);
            }
        }];
    }
}

%end
