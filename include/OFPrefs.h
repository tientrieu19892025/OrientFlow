#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define kOrientFlowPrefsNotification "com.jinken.orientflow/ReloadPrefs"
#define kOrientFlowPrefsDomain @"com.jinken.orientflow"

@interface OFPrefs : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) CGFloat duration;
@property (nonatomic, assign) BOOL hapticFeedback;
@property (nonatomic, assign) NSInteger position; // 0 = Bottom Right, 1 = Bottom Left, 2 = Top Right, 3 = Dynamic
@property (nonatomic, assign) BOOL autoRelockOnPortrait;

+ (instancetype)sharedInstance;
- (void)loadSettings;

@end
