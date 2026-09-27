#import <Foundation/Foundation.h>

static inline BOOL OFIsEnglish(void) {
    // 0 = Auto, 1 = Vietnamese, 2 = English
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.jinken.orientflow.plist"];
    NSInteger lang = [dict[@"language"] integerValue];
    if (lang == 2) return YES;
    if (lang == 1) return NO;
    NSString *cur = [[NSLocale preferredLanguages] firstObject] ?: @"";
    return ![cur hasPrefix:@"vi"];
}

static inline NSString *OFLoc(NSString *key) {
    BOOL en = OFIsEnglish();
    static NSDictionary *viDict = nil;
    static NSDictionary *enDict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        viDict = @{
            @"hero_sub": @"Gợi ý xoay màn hình thông minh khi khoá xoay",
            @"hero_desc": @"v1.0.2 · Jinken Nguyen - 1989\niOS 13 – 26 · Rootless · Rootful · RootHide",
            @"sec_general": @"CÀI ĐẶT CHUNG",
            @"enabled": @"Bật OrientFlow",
            @"enabled_sub": @"Kích hoạt gợi ý xoay màn hình thông minh.",
            @"haptic": @"Rung phản hồi (Haptic)",
            @"haptic_sub": @"Tạo cảm giác rung nhẹ khi nút xuất hiện và chạm vào.",
            @"relock": @"Tự khoá lại khi về dọc",
            @"relock_sub": @"Tự động bật lại khoá xoay khi dựng điện thoại đứng trở lại.",
            @"sec_appearance": @"GIAO DIỆN & VỊ TRÍ",
            @"duration_title": @"Thời gian hiển thị (giây)",
            @"pos_title": @"Vị trí nút bấm",
            @"pos_br": @"Dưới Phải",
            @"pos_bl": @"Dưới Trái",
            @"pos_tr": @"Trên Phải",
            @"sec_language": @"NGÔN NGỮ",
            @"lang_auto": @"Tự động",
            @"lang_vi": @"Tiếng Việt",
            @"lang_en": @"English",
            @"sec_actions": @"THAO TÁC HỆ THỐNG",
            @"respring": @"Áp dụng & Respring",
            @"sec_donate": @"ỦNG HỘ TÁC GIẢ (DONATE)",
            @"donate_info": @"Ngân hàng: MB Bank\nSố tài khoản: 0345140889\nChủ tài khoản: NGUYEN TIEN TRIEU\nỦng hộ nhà phát triển để duy trì & phát triển tweak!",
            @"copy_account": @"Sao chép số tài khoản (MB Bank)",
            @"copy_done": @"Đã sao chép 0345140889 vào khay nhớ tạm!",
            @"sec_intl_donate": @"ỦNG HỘ QUỐC TẾ",
            @"credit_footer": @"OrientFlow © 2026 Jin Ken Nguyen - 1989.\nThiết kế hiệu năng cao, siêu mượt, không đơ lag, không hao pin."
        };

        enDict = @{
            @"hero_sub": @"Smart rotation suggestion popup when lock is active",
            @"hero_desc": @"v1.0.2 · Jinken Nguyen - 1989\niOS 13 – 26 · Rootless · Rootful · RootHide",
            @"sec_general": @"GENERAL SETTINGS",
            @"enabled": @"Enable OrientFlow",
            @"enabled_sub": @"Activate smart screen rotation suggestion prompt.",
            @"haptic": @"Haptic Feedback",
            @"haptic_sub": @"Tactile vibration feedback on button appearance & tap.",
            @"relock": @"Auto Re-lock on Portrait",
            @"relock_sub": @"Automatically re-engage orientation lock when held upright.",
            @"sec_appearance": @"APPEARANCE & POSITION",
            @"duration_title": @"Display Duration (seconds)",
            @"pos_title": @"Button Position",
            @"pos_br": @"Bottom Right",
            @"pos_bl": @"Bottom Left",
            @"pos_tr": @"Top Right",
            @"sec_language": @"LANGUAGE",
            @"lang_auto": @"Auto",
            @"lang_vi": @"Tiếng Việt",
            @"lang_en": @"English",
            @"sec_actions": @"SYSTEM ACTIONS",
            @"respring": @"Apply & Respring",
            @"sec_donate": @"SUPPORT & DONATE",
            @"donate_info": @"Bank: MB Bank\nAccount: 0345140889\nBeneficiary: NGUYEN TIEN TRIEU\nSupport the developer to maintain & build future tweaks!",
            @"copy_account": @"Copy Bank Account (MB Bank)",
            @"copy_done": @"Copied 0345140889 to clipboard!",
            @"sec_intl_donate": @"INTERNATIONAL SUPPORT",
            @"credit_footer": @"OrientFlow © 2026 Jin Ken Nguyen - 1989.\nHigh-performance, ultra smooth, zero lag, zero battery drain."
        };
    });

    NSDictionary *d = en ? enDict : viDict;
    return d[key] ?: key;
}
