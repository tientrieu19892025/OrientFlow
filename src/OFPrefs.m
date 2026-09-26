#import "OFPrefs.h"

@implementation OFPrefs

+ (instancetype)sharedInstance {
    static OFPrefs *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OFPrefs alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    NSDictionary *prefs = nil;
    CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)kOrientFlowPrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keyList) {
        prefs = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList, (CFStringRef)kOrientFlowPrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFRelease(keyList);
    }

    if (!prefs) {
        NSString *path = @"/var/mobile/Library/Preferences/com.jinken.orientflow.plist";
        prefs = [NSDictionary dictionaryWithContentsOfFile:path];
    }

    self.enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
    self.duration = prefs[@"duration"] ? [prefs[@"duration"] doubleValue] : 3.5;
    if (self.duration < 1.5) self.duration = 1.5;
    if (self.duration > 8.0) self.duration = 8.0;

    self.hapticFeedback = prefs[@"hapticFeedback"] ? [prefs[@"hapticFeedback"] boolValue] : YES;
    self.position = prefs[@"position"] ? [prefs[@"position"] integerValue] : 0;
    self.autoRelockOnPortrait = prefs[@"autoRelockOnPortrait"] ? [prefs[@"autoRelockOnPortrait"] boolValue] : YES;
}

@end
