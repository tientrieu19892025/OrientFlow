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
@end

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

@interface SpringBoard : UIApplication
- (BOOL)isLocked;
- (SBApplication *)_accessibilityFrontMostApplication;
@end

static CMMotionManager *motionMgr = nil;
static UIInterfaceOrientation candidateOrientation = UIInterfaceOrientationUnknown;
static UIInterfaceOrientation activeLandscapeOrientation = UIInterfaceOrientationUnknown;
static NSTimeInterval lastTriggerTime = 0;
static BOOL tempUnlockedForSession = NO;
static BOOL isRelocking = NO;

// Thread-safe cached system states updated exclusively on main thread
static NSString *gCurrentActiveBundleID = @"com.apple.springboard";
static BOOL gIsScreenLocked = NO;

static void SafeUnlockAndRotateToOrientation(UIInterfaceOrientation targetOrientation) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SafeUnlockAndRotateToOrientation(targetOrientation);
        });
        return;
    }

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
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SafeRelockOrientation();
        });
        return;
    }

    if (isRelocking) return;
    isRelocking = YES;

    @try {
        Class lockClass = objc_getClass("SBOrientationLockManager");
        if (lockClass) {
            SBOrientationLockManager *mgr = [lockClass sharedInstance];
            if (mgr) {
                tempUnlockedForSession = NO;
                activeLandscapeOrientation = UIInterfaceOrientationUnknown;
                candidateOrientation = UIInterfaceOrientationUnknown;
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
    } @finally {
        isRelocking = NO;
    }
}

static void ReloadPrefsCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[OFPrefs sharedInstance] loadSettings];
}

static void SystemLockStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gIsScreenLocked = YES;
        if (tempUnlockedForSession) {
            SafeRelockOrientation();
        }
        if ([[OFButtonWindow sharedWindow] isPromptShowing]) {
            [[OFButtonWindow sharedWindow] hidePrompt];
        }
    });
}

static void ProcessDeviceMotion(CMDeviceMotion *motion) {
    @try {
        OFPrefs *prefs = [OFPrefs sharedInstance];
        if (!prefs.enabled) return;

        // Check lock screen using cached thread-safe flag
        if (gIsScreenLocked && prefs.disableOnLockScreen) {
            return;
        }

        // Check allowed app using cached thread-safe bundle ID
        if (![prefs isAppAllowed:gCurrentActiveBundleID]) {
            return;
        }

        Class lockClass = objc_getClass("SBOrientationLockManager");
        if (!lockClass) return;

        SBOrientationLockManager *lockMgr = [lockClass sharedInstance];
        if (!lockMgr) return;

        BOOL isLocked = [lockMgr respondsToSelector:@selector(isUserLocked)] ? [lockMgr isUserLocked] : NO;
        if (!isLocked && !tempUnlockedForSession) {
            // User turned off orientation lock in Control Center -> device auto-rotates freely, tweak does nothing
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
            if (!prefs.lockLandscapeMode || prefs.autoRelockOnPortrait) {
                if (tempUnlockedForSession) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        SafeRelockOrientation();
                    });
                } else {
                    activeLandscapeOrientation = UIInterfaceOrientationUnknown;
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

        // If user already tapped and confirmed this orientation, do not prompt again
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

- (void)frontDisplayDidChange:(id)newDisplay {
    %orig;

    NSString *bundleID = nil;
    if (newDisplay && [newDisplay respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [newDisplay bundleIdentifier];
    }
    gCurrentActiveBundleID = [bundleID copy] ?: @"com.apple.springboard";

    // Whenever user switches apps or exits to Homescreen, restore portrait orientation lock immediately
    if (tempUnlockedForSession) {
        SafeRelockOrientation();
    }

    if ([[OFButtonWindow sharedWindow] isPromptShowing]) {
        [[OFButtonWindow sharedWindow] hidePrompt];
    }
}

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

    // Monitor device lock and screen-off events to safely relock orientation
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        SystemLockStateChanged,
        CFSTR("com.apple.springboard.lockstate"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        SystemLockStateChanged,
        CFSTR("com.apple.springboard.hasBlankedScreen"),
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

%hook SBLockScreenManager

- (void)_setUILocked:(BOOL)locked {
    %orig;
    gIsScreenLocked = locked;
    if (locked && tempUnlockedForSession) {
        SafeRelockOrientation();
    }
}

%end
