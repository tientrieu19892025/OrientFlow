#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import "OFPrefs.h"
#import "OFButtonWindow.h"

@interface SBOrientationLockManager : NSObject
+ (id)sharedInstance;
- (BOOL)isUserLocked;
- (void)lock;
- (void)unlock;
- (NSInteger)userLockOrientation;
- (NSInteger)effectiveLockedOrientation;
@end

static CMMotionManager *motionMgr = nil;
static UIInterfaceOrientation candidateOrientation = UIInterfaceOrientationUnknown;
static NSTimeInterval lastTriggerTime = 0;
static BOOL tempUnlockedForSession = NO;

static void SafeUnlockOrientation(void) {
    @try {
        Class lockClass = objc_getClass("SBOrientationLockManager");
        if (lockClass) {
            SBOrientationLockManager *mgr = [lockClass sharedInstance];
            if (mgr && [mgr respondsToSelector:@selector(isUserLocked)] && [mgr isUserLocked]) {
                tempUnlockedForSession = YES;
                if ([mgr respondsToSelector:@selector(unlock)]) {
                    [mgr unlock];
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in SafeUnlockOrientation: %@", e);
    }
}

static void SafeRelockOrientation(void) {
    @try {
        Class lockClass = objc_getClass("SBOrientationLockManager");
        if (lockClass) {
            SBOrientationLockManager *mgr = [lockClass sharedInstance];
            if (mgr) {
                tempUnlockedForSession = NO;
                if ([mgr respondsToSelector:@selector(lock)]) {
                    [mgr lock];
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in SafeRelockOrientation: %@", e);
    }
}

static void ReloadPrefsCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[OFPrefs sharedInstance] loadSettings];
}

static void ProcessDeviceMotion(CMDeviceMotion *motion) {
    OFPrefs *prefs = [OFPrefs sharedInstance];
    if (!prefs.enabled) return;

    Class lockClass = objc_getClass("SBOrientationLockManager");
    if (!lockClass) return;

    SBOrientationLockManager *lockMgr = [lockClass sharedInstance];
    if (!lockMgr) return;

    BOOL isLocked = [lockMgr respondsToSelector:@selector(isUserLocked)] ? [lockMgr isUserLocked] : NO;
    if (!isLocked && !tempUnlockedForSession) {
        return; // Device is not locked and not temporarily unlocked -> do nothing
    }

    double gx = motion.gravity.x;
    double gy = motion.gravity.y;
    double gz = motion.gravity.z;

    // Ignore flat phone on table
    if (fabs(gz) > 0.85) {
        return;
    }

    UIInterfaceOrientation target = UIInterfaceOrientationUnknown;

    // Landscape detection
    if (fabs(gx) > 0.70 && fabs(gy) < 0.45) {
        if (gx > 0.70) {
            target = UIInterfaceOrientationLandscapeLeft;
        } else if (gx < -0.70) {
            target = UIInterfaceOrientationLandscapeRight;
        }
    } else if (gy < -0.75 && fabs(gx) < 0.40) {
        // Device is held upright in Portrait
        if (tempUnlockedForSession && prefs.autoRelockOnPortrait) {
            dispatch_async(dispatch_get_main_queue(), ^{
                SafeRelockOrientation();
            });
        }
        return;
    }

    if (target == UIInterfaceOrientationUnknown) {
        return;
    }

    NSInteger currentLocked = [lockMgr respondsToSelector:@selector(userLockOrientation)] ? [lockMgr userLockOrientation] : 0;
    if (target == (UIInterfaceOrientation)currentLocked && isLocked) {
        return;
    }

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - lastTriggerTime < 2.0) {
        return;
    }

    candidateOrientation = target;
    lastTriggerTime = now;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[OFButtonWindow sharedWindow] showPromptWithOrientation:target tapHandler:^{
            SafeUnlockOrientation();
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

    // 6Hz is extremely gentle on CPU (< 0.2%) while still responding within ~160ms of rotation
    motionMgr = [[CMMotionManager alloc] init];
    motionMgr.deviceMotionUpdateInterval = 0.16;

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.name = @"com.jinken.orientflow.sensorQueue";
    queue.qualityOfService = NSQualityOfServiceUtility;

    if (motionMgr.isDeviceMotionAvailable) {
        [motionMgr startDeviceMotionUpdatesToQueue:queue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            if (motion && !error) {
                ProcessDeviceMotion(motion);
            }
        }];
    }
}

%end
