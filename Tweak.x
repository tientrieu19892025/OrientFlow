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

@interface SBLockScreenManager : NSObject
+ (id)sharedInstance;
- (BOOL)isUILocked;
@end

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

@interface SpringBoard : UIApplication
- (SBApplication *)_accessibilityFrontMostApplication;
@end

static CMMotionManager *motionMgr = nil;
static UIInterfaceOrientation candidateOrientation = UIInterfaceOrientationUnknown;
static UIInterfaceOrientation activeLandscapeOrientation = UIInterfaceOrientationUnknown;
static BOOL gOrientFlowLockedLandscape = NO;
static UIInterfaceOrientation gOrientFlowLockedOrientation = UIInterfaceOrientationUnknown;
static NSTimeInterval lastTriggerTime = 0;
static NSString *lastActiveBundleID = nil;

static void SafeUnlockAndRotateToOrientation(UIInterfaceOrientation targetOrientation) {
    @try {
        gOrientFlowLockedOrientation = targetOrientation;
        gOrientFlowLockedLandscape = YES;
        activeLandscapeOrientation = targetOrientation;

        Class lockClass = objc_getClass("SBOrientationLockManager");
        if (lockClass) {
            SBOrientationLockManager *mgr = [lockClass sharedInstance];
            if (mgr) {
                if ([mgr respondsToSelector:@selector(unlock)]) {
                    [mgr unlock];
                }
                
                // Re-engage system lock with new landscape orientation so Control Center stays active
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        if (gOrientFlowLockedLandscape && [mgr respondsToSelector:@selector(lock)]) {
                            [mgr lock];
                        }
                    } @catch (NSException *lkEx) {}
                });
            }
        }

        // Inform UIDevice to force rotate view controllers to the confirmed landscape orientation
        if (@available(iOS 16.0, *)) {
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
        
        UIDeviceOrientation devOrient = (targetOrientation == UIInterfaceOrientationLandscapeLeft) ? 
            UIDeviceOrientationLandscapeRight : UIDeviceOrientationLandscapeLeft;
        @try {
            [[UIDevice currentDevice] setValue:@(devOrient) forKey:@"orientation"];
        } @catch (NSException *ex) {}

        [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
    } @catch (NSException *e) {
        NSLog(@"[OrientFlow] Exception in SafeUnlockAndRotate: %@", e);
    }
}

static void SafeRelockOrientation(void) {
    @try {
        gOrientFlowLockedLandscape = NO;
        gOrientFlowLockedOrientation = UIInterfaceOrientationPortrait;
        activeLandscapeOrientation = UIInterfaceOrientationUnknown;

        Class lockClass = objc_getClass("SBOrientationLockManager");
        if (lockClass) {
            SBOrientationLockManager *mgr = [lockClass sharedInstance];
            if (mgr) {
                if ([mgr respondsToSelector:@selector(unlock)]) {
                    [mgr unlock];
                }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        if ([mgr respondsToSelector:@selector(lock)]) {
                            [mgr lock];
                        }
                    } @catch (NSException *lEx) {}
                });
            }
        }
        
        // Notify device back to portrait
        if (@available(iOS 16.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    SEL updateSel = NSSelectorFromString(@"requestGeometryUpdateWithPreferences:errorHandler:");
                    if ([windowScene respondsToSelector:updateSel]) {
                        Class prefClass = NSClassFromString(@"UIWindowSceneGeometryPreferencesIOS");
                        if (prefClass) {
                            id prefsObj = [[prefClass alloc] init];
                            if ([prefsObj respondsToSelector:@selector(setInterfaceOrientations:)]) {
                                [prefsObj setValue:@(UIInterfaceOrientationMaskPortrait) forKey:@"interfaceOrientations"];
                                [windowScene performSelector:updateSel withObject:prefsObj withObject:nil];
                            }
                        }
                    }
                    #pragma clang diagnostic pop
                }
            }
        }

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
        if (!isLocked && !gOrientFlowLockedLandscape) {
            // Orientation lock is OFF in Control Center -> iOS runs free auto-rotation! OrientFlow does not interfere!
            return;
        }

        // Check Lock Screen
        BOOL isLockScreen = NO;
        Class lsClass = objc_getClass("SBLockScreenManager");
        if (lsClass) {
            SBLockScreenManager *lsMgr = [lsClass sharedInstance];
            if ([lsMgr respondsToSelector:@selector(isUILocked)]) {
                isLockScreen = [lsMgr isUILocked];
            }
        }
        if (isLockScreen) {
            if (gOrientFlowLockedLandscape) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    SafeRelockOrientation();
                });
            }
            if (prefs.disableOnLockScreen) {
                if ([[OFButtonWindow sharedWindow] isPromptShowing]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[OFButtonWindow sharedWindow] hidePrompt];
                    });
                }
                return;
            }
        }

        // Check Active Application
        SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
        SBApplication *frontApp = nil;
        if ([sb respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
            frontApp = [sb _accessibilityFrontMostApplication];
        }
        NSString *currentBundleID = frontApp ? [frontApp bundleIdentifier] : @"com.apple.springboard";

        // If app changed while in locked landscape session, safely relock to portrait
        if (lastActiveBundleID && ![lastActiveBundleID isEqualToString:currentBundleID]) {
            if (gOrientFlowLockedLandscape) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    SafeRelockOrientation();
                });
            }
        }
        lastActiveBundleID = currentBundleID;

        // Check if current app is allowed
        if (![prefs isAppAllowed:currentBundleID]) {
            if ([[OFButtonWindow sharedWindow] isPromptShowing]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[OFButtonWindow sharedWindow] hidePrompt];
                });
            }
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
            if (prefs.autoRelockOnPortrait || !prefs.lockLandscapeMode) {
                if (gOrientFlowLockedLandscape || activeLandscapeOrientation != UIInterfaceOrientationUnknown) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        SafeRelockOrientation();
                    });
                }
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

        // If user already tapped and accepted this exact landscape orientation, DO NOT show prompt again
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

%hook SBOrientationLockManager

- (NSInteger)userLockOrientation {
    if (gOrientFlowLockedLandscape && gOrientFlowLockedOrientation != UIInterfaceOrientationUnknown) {
        return (NSInteger)gOrientFlowLockedOrientation;
    }
    return %orig;
}

- (NSInteger)effectiveLockedOrientation {
    if (gOrientFlowLockedLandscape && gOrientFlowLockedOrientation != UIInterfaceOrientationUnknown) {
        return (NSInteger)gOrientFlowLockedOrientation;
    }
    return %orig;
}

%end

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

    // 6Hz is gentle on CPU (< 0.2%) while responding within ~160ms of rotation
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
