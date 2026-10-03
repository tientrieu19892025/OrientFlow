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
    self.offsetX = prefs[@"offsetX"] ? [prefs[@"offsetX"] doubleValue] : 85.0; // default 85% width (right side)
    self.offsetY = prefs[@"offsetY"] ? [prefs[@"offsetY"] doubleValue] : 90.0; // default 90% height (bottom side)
    if (self.offsetX < 5.0) self.offsetX = 5.0;
    if (self.offsetX > 95.0) self.offsetX = 95.0;
    if (self.offsetY < 5.0) self.offsetY = 5.0;
    if (self.offsetY > 95.0) self.offsetY = 95.0;
    self.autoRelockOnPortrait = prefs[@"autoRelockOnPortrait"] ? [prefs[@"autoRelockOnPortrait"] boolValue] : YES;
    self.lockLandscapeMode = prefs[@"lockLandscapeMode"] ? [prefs[@"lockLandscapeMode"] boolValue] : NO;
    self.disableOnLockScreen = prefs[@"disableOnLockScreen"] ? [prefs[@"disableOnLockScreen"] boolValue] : YES;
    self.disableOnHomeScreen = prefs[@"disableOnHomeScreen"] ? [prefs[@"disableOnHomeScreen"] boolValue] : NO;
    self.appSelectionMode = prefs[@"appSelectionMode"] ? [prefs[@"appSelectionMode"] integerValue] : 0;
    
    NSDictionary *apps = prefs[@"selectedApps"];
    if ([apps isKindOfClass:[NSDictionary class]]) {
        self.selectedApps = apps;
    } else {
        self.selectedApps = @{};
    }

    self.language = prefs[@"language"] ? [prefs[@"language"] integerValue] : 0;
}

- (BOOL)isAppAllowed:(NSString *)bundleID {
    if (!bundleID || [bundleID length] == 0) {
        return !self.disableOnHomeScreen;
    }
    if ([bundleID isEqualToString:@"com.apple.springboard"]) {
        return !self.disableOnHomeScreen;
    }
    if (self.appSelectionMode == 0) {
        return YES; // All apps allowed
    }
    BOOL isSelected = [self.selectedApps[bundleID] boolValue];
    if (self.appSelectionMode == 1) {
        // Whitelist: Only selected apps allowed
        return isSelected;
    } else if (self.appSelectionMode == 2) {
        // Blacklist: Exclude selected apps
        return !isSelected;
    }
    return YES;
}

- (void)saveKey:(NSString *)key value:(id)val {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)val, (CFStringRef)kOrientFlowPrefsDomain);
    CFPreferencesAppSynchronize((CFStringRef)kOrientFlowPrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(kOrientFlowPrefsNotification), NULL, NULL, YES);
    [self loadSettings];
}

@end
