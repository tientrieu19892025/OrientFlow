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
static UIInterfaceOrientation activeLandscapeOrientation = UIInterfaceOrientationUnknown;
static NSTimeInterval lastTriggerTime = 0;
static BOOL tempUnlockedForSession = NO;

static void SafeUnlockAndRotateToOrientation(UIInterfaceOrientation targetOrientation) {
    @try {
        Class lockClass = objc_getClass("SBOrientationLockManager");
        if (lockClass) {
            SBOrientationLockManager *mgr = [lockClass sharedInstance];
            if (mgr) {
                tempUnlockedForSession = YES;
                activeLandscapeOrientation = targetOrientation;
                if ([mgr respondsToSelector:@selector(isUserLocked)] && [mgr isUserLocked]) {
                    if ([mgr respondsToSelector:@selector(unlock)]) {
                        [mgr unlock];
                    }
                }
            }
        }

        // Inform UIDevice to force rotate view controllers to the confirmed landscape orientation
        if (@available(iOS 16.0, *)) {
            // On iOS 16+, trigger geometry update if possible
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    UIInterfaceOrientationMask mask = (targetOrientation == UIInterfaceOrientationLandscapeLeft) ? 
                        UIInterfaceOrientationMaskLandscapeLeft : UIInterfaceOrientationMaskLandscapeRight;
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    SEL updateSel = NSSelectorFromString(@"requestGeometryUpdateWithPreferences:errorHandler:");
                    if ([windowScene respondsToSelector:updateSel]) {
                        Class prefClass = NSClassFromString(@"UIWindowSceneGeometryPreferencesIOS");
                        if (prefClass) {
                            id prefsObj = [[prefClass alloc] init];
                            if ([prefsObj respondsToSelector:@selector(setInterfaceOrientations:)]) {
                                [prefsObj setValue:@(mask) forKey:@"interfaceOrientations"];
                                [windowScene performSelector:updateSel withObject:prefsObj withObject:nil];
                            }
                        }
                    }
                    #pragma clang diagnostic pop
                }
            }
        }
        
        // Also trigger UIDevice orientation notification so apps reorient immediately
        UIDeviceOrientation devOrient = (targetOrientation == UIInterfaceOrientationLandscapeLeft) ? 
            UIDeviceOrientationLandscapeRight : UIDeviceOrientationLandscapeLeft;
        @try {
            [[UIDevice currentDevice] setValue:@(devOrient) forKey:@"orientation"];
        } @catch (NSException *ex) {}

        // Send orientation changed notification to SpringBoard and active apps
        [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in SafeUnlockAndRotate: %@", e);
    }
}

static void SafeRelockOrientation(void) {
    @try {
        Class lockClass = objc_getClass("SBOrientationLockManager");
        if (lockClass) {
            SBOrientationLockManager *mgr = [lockClass sharedInstance];
            if (mgr) {
                tempUnlockedForSession = NO;
                activeLandscapeOrientation = UIInterfaceOrientationUnknown;
                if ([mgr respondsToSelector:@selector(lock)]) {
                    [mgr lock];
                }
            }
        }
        
        // Notify device back to portrait
        @try {
            [[UIDevice currentDevice] setValue:@(UIDeviceOrientationPortrait) forKey:@"orientation"];
        } @catch (NSException *ex) {}
        [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in SafeRelockOrientation: %@", e);
    }
}

static void ReloadPrefsCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[OFPrefs sharedInstance] loadSettings];
}

static void ProcessDeviceMotion(CMDeviceMotion *motion) {
    @try {
        OFPrefs *prefs = [OFPrefs sharedInstance];
        if (!prefs.enabled) return;

        Class lockClass = objc_getClass("SBOrientationLockManager");
        if (!lockClass) return;

        SBOrientationLockManager *lockMgr = [lockClass sharedInstance];
        if (!lockMgr) return;

        BOOL isLocked = [lockMgr respondsToSelector:@selector(isUserLocked)] ? [lockMgr isUserLocked] : NO;
        if (!isLocked && !tempUnlockedForSession) {
            // Device is not locked and not in a temporary unlocked session -> do nothing
            return;
        }

        double gx = motion.gravity.x;
        double gy = motion.gravity.y;
        double gz = motion.gravity.z;

        // Ignore flat phone on table
        if (fabs(gz) > 0.85) {
            return;
        }

        UIInterfaceOrientation target = UIInterfaceOrientationUnknown;

        // Landscape detection (gx > 0.65 => LandscapeLeft; gx < -0.65 => LandscapeRight)
        if (fabs(gx) > 0.65 && fabs(gy) < 0.50) {
            if (gx > 0.65) {
                target = UIInterfaceOrientationLandscapeLeft;
            } else if (gx < -0.65) {
                target = UIInterfaceOrientationLandscapeRight;
            }
        } else if (gy < -0.70 && fabs(gx) < 0.45) {
            // Device is held upright in Portrait
            if (tempUnlockedForSession && prefs.autoRelockOnPortrait) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    SafeRelockOrientation();
                });
            } else {
                activeLandscapeOrientation = UIInterfaceOrientationUnknown;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {
                    if ([[OFButtonWindow sharedWindow] isPromptShowing]) {
                        [[OFButtonWindow sharedWindow] hidePrompt];
                    }
                } @catch (NSException *ex) {}
            });
            return;
        }

        if (target == UIInterfaceOrientationUnknown) {
            return;
        }

        // 1. If user already tapped and accepted this exact landscape orientation, DO NOT show prompt again!
        if (activeLandscapeOrientation == target) {
            return;
        }

        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        // Cooldown 3.5 seconds between prompts for same target
        if (candidateOrientation == target && (now - lastTriggerTime < 3.5)) {
            return;
        }

        candidateOrientation = target;
        lastTriggerTime = now;

        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                if ([[OFButtonWindow sharedWindow] isPromptShowing]) {
                    return;
                }
                [[OFButtonWindow sharedWindow] showPromptWithOrientation:target tapHandler:^{
                    SafeUnlockAndRotateToOrientation(target);
                }];
            } @catch (NSException *showEx) {
                NSLog(@"[OrientFlow] Exception in showPrompt dispatch: %@", showEx);
            }
        });
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in ProcessDeviceMotion: %@", e);
    }
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
