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
            @"hero_desc": @"v1.0.8 · Jinken Nguyen - 1989\niOS 13 – 26 · Rootless · Rootful · RootHide",
            @"sec_general": @"CÀI ĐẶT CHUNG",
            @"enabled": @"Bật OrientFlow",
            @"enabled_sub": @"Kích hoạt gợi ý xoay màn hình thông minh.",
            @"haptic": @"Rung phản hồi (Haptic)",
            @"haptic_sub": @"Tạo cảm giác rung nhẹ khi nút xuất hiện và chạm vào.",
            @"relock": @"Tự khoá lại khi về dọc",
            @"relock_sub": @"Tự động bật lại khoá xoay khi dựng điện thoại đứng trở lại.",
            @"lock_landscape": @"Giữ khoá ngang sau khi bấm",
            @"lock_landscape_sub": @"Khoá cố định ở hướng ngang, không tự do xoay lung tung.",
            @"disable_ls": @"Tắt ở Màn hình khoá",
            @"disable_ls_sub": @"Không hiển thị nút xoay khi đang ở màn hình khoá.",
            @"disable_hs": @"Tắt ở Màn hình chính",
            @"disable_hs_sub": @"Không hiển thị nút xoay khi đang ở màn hình chính.",
            @"sec_app_selection": @"ỨNG DỤNG ÁP DỤNG",
            @"app_mode_title": @"Chế độ áp dụng",
            @"app_mode_all": @"Tất cả",
            @"app_mode_whitelist": @"Đã chọn",
            @"app_mode_blacklist": @"Loại trừ",
            @"app_choose_btn": @"Danh sách ứng dụng kích hoạt",
            @"app_list_title": @"Chọn Ứng Dụng",
            @"search_apps": @"Tìm kiếm ứng dụng...",
            @"select_all": @"Chọn hết",
            @"deselect_all": @"Bỏ chọn",
            @"sec_appearance": @"GIAO DIỆN & VỊ TRÍ",
            @"duration_title": @"Thời gian hiển thị (giây)",
            @"pos_title": @"Vị trí nút bấm",
            @"pos_br": @"Dưới Phải",
            @"pos_bl": @"Dưới Trái",
            @"pos_tr": @"Trên Phải",
            @"pos_custom": @"Tuỳ chỉnh",
            @"pos_offset_x": @"Vị trí Ngang (Trái ↔ Phải)",
            @"pos_offset_y": @"Vị trí Dọc (Trên ↕ Dưới)",
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
            @"hero_desc": @"v1.0.8 · Jinken Nguyen - 1989\niOS 13 – 26 · Rootless · Rootful · RootHide",
            @"sec_general": @"GENERAL SETTINGS",
            @"enabled": @"Enable OrientFlow",
            @"enabled_sub": @"Activate smart screen rotation suggestion prompt.",
            @"haptic": @"Haptic Feedback",
            @"haptic_sub": @"Tactile vibration feedback on button appearance & tap.",
            @"relock": @"Auto Re-lock on Portrait",
            @"relock_sub": @"Automatically re-engage orientation lock when held upright.",
            @"lock_landscape": @"Stay Locked in Landscape",
            @"lock_landscape_sub": @"Lock screen in landscape mode without unwanted auto-rotation.",
            @"disable_ls": @"Disable on Lock Screen",
            @"disable_ls_sub": @"Never show rotation button on the lock screen.",
            @"disable_hs": @"Disable on Home Screen",
            @"disable_hs_sub": @"Never show rotation button on the home screen.",
            @"sec_app_selection": @"APPLICATION FILTER",
            @"app_mode_title": @"Filter Mode",
            @"app_mode_all": @"All Apps",
            @"app_mode_whitelist": @"Whitelist",
            @"app_mode_blacklist": @"Blacklist",
            @"app_choose_btn": @"Choose Applications...",
            @"app_list_title": @"Select Applications",
            @"search_apps": @"Search apps...",
            @"select_all": @"Select All",
            @"deselect_all": @"Deselect All",
            @"sec_appearance": @"APPEARANCE & POSITION",
            @"duration_title": @"Display Duration (seconds)",
            @"pos_title": @"Button Position",
            @"pos_br": @"Bottom Right",
            @"pos_bl": @"Bottom Left",
            @"pos_tr": @"Top Right",
            @"pos_custom": @"Custom",
            @"pos_offset_x": @"Horizontal Position (Left ↔ Right)",
            @"pos_offset_y": @"Vertical Position (Top ↕ Bottom)",
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
