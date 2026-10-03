#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define kOrientFlowPrefsNotification "com.jinken.orientflow/ReloadPrefs"
#define kOrientFlowPrefsDomain @"com.jinken.orientflow"

@interface OFPrefs : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) CGFloat duration;
@property (nonatomic, assign) BOOL hapticFeedback;
@property (nonatomic, assign) NSInteger position; // 0 = Bottom Right, 1 = Bottom Left, 2 = Top Right, 3 = Custom (Sliders)
@property (nonatomic, assign) CGFloat offsetX; // 0 to 100 (% of screen width)
@property (nonatomic, assign) CGFloat offsetY; // 0 to 100 (% of screen height)
@property (nonatomic, assign) BOOL autoRelockOnPortrait;
@property (nonatomic, assign) BOOL lockLandscapeMode;
@property (nonatomic, assign) BOOL disableOnLockScreen; // YES by default
@property (nonatomic, assign) BOOL disableOnHomeScreen; // NO by default
@property (nonatomic, assign) NSInteger appSelectionMode; // 0 = All Apps, 1 = Whitelist (Only Selected), 2 = Blacklist (Exclude Selected)
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *selectedApps;
@property (nonatomic, assign) NSInteger language; // 0 = Auto, 1 = Vietnamese, 2 = English

+ (instancetype)sharedInstance;
- (void)loadSettings;
- (void)saveKey:(NSString *)key value:(id)val;
- (BOOL)isAppAllowed:(NSString *)bundleID;

@end
