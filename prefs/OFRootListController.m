#import "OFRootListController.h"
#import "../include/OFPrefs.h"
#import <spawn.h>

#if __has_include(<rootless.h>)
#import <rootless.h>
#endif
#ifndef ROOT_PATH
#define ROOT_PATH(x) (x)
#endif

@interface OFRootListController () {
    UIScrollView *_scroll;
    UIView *_content;
    CGFloat _laidWidth;
}
@end

@implementation OFRootListController

- (id)specifiers {
    return @[];
}

- (void)loadView {
    [super loadView];
    self.title = @"OrientFlow";
    
    _scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.alwaysBounceVertical = YES;
    _scroll.showsVerticalScrollIndicator = YES;
    [self.view addSubview:_scroll];
    
    _content = [[UIView alloc] initWithFrame:self.view.bounds];
    [_scroll addSubview:_content];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self rebuild];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self hideStockTable];
    [self rebuild];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    if (fabs(_laidWidth - w) > 1.0) {
        [self rebuild];
    }
}

- (void)hideStockTable {
    UITableView *tv = nil;
    @try { tv = [self valueForKey:@"table"]; } @catch (NSException *e) {}
    if ([tv isKindOfClass:[UITableView class]]) {
        tv.hidden = YES;
        tv.userInteractionEnabled = NO;
    }
}

- (UIView *)cardView {
    UIView *c = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        c.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        c.layer.cornerCurve = kCACornerCurveContinuous;
    } else {
        c.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    }
    c.layer.cornerRadius = 18;
    c.clipsToBounds = YES;
    return c;
}

- (void)rebuild {
    for (UIView *v in _content.subviews) [v removeFromSuperview];
    CGFloat w = self.view.bounds.size.width;
    if (w < 2) w = [UIScreen mainScreen].bounds.size.width;
    _laidWidth = w;
    CGFloat x = 16, inner = w - 32, y = 14;
    
    OFPrefs *prefs = [OFPrefs sharedInstance];
    [prefs loadSettings];

    // 1. Hero Banner
    UIView *hero = [self cardView];
    hero.frame = CGRectMake(x, y, inner, 120);
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.colors = @[
        (id)[UIColor colorWithRed:0.12 green:0.53 blue:0.90 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.35 green:0.25 blue:0.85 alpha:1.0].CGColor
    ];
    grad.startPoint = CGPointMake(0, 0);
    grad.endPoint = CGPointMake(1, 1);
    grad.frame = CGRectMake(0, 0, inner, 120);
    grad.cornerRadius = 18;
    if (@available(iOS 13.0, *)) grad.cornerCurve = kCACornerCurveContinuous;
    [hero.layer insertSublayer:grad atIndex:0];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, inner - 40, 32)];
    title.text = @"OrientFlow";
    title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    [hero addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(20, 48, inner - 40, 22)];
    sub.text = @"Smart Rotate Suggestion • Gợi ý xoay thông minh";
    sub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    sub.textColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    [hero addSubview:sub];

    UILabel *meta = [[UILabel alloc] initWithFrame:CGRectMake(20, 72, inner - 40, 34)];
    meta.text = @"v1.0.0 · Jinken Nguyen - 1989\nRootless · Rootful · RootHide · Zero Lag";
    meta.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    meta.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    meta.numberOfLines = 2;
    [hero addSubview:meta];

    [_content addSubview:hero];
    y += 134;

    // 2. Settings Section
    UILabel *sec1 = [[UILabel alloc] initWithFrame:CGRectMake(x + 4, y, inner, 22)];
    sec1.text = @"CẤU HÌNH & TÍNH NĂNG";
    sec1.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    sec1.textColor = [UIColor secondaryLabelColor];
    [_content addSubview:sec1];
    y += 28;

    UIView *box1 = [self cardView];
    box1.frame = CGRectMake(x, y, inner, 168);
    
    // Switch 1: Enabled
    UILabel *lbl1 = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, inner - 100, 24)];
    lbl1.text = @"Bật OrientFlow";
    lbl1.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [box1 addSubview:lbl1];
    
    UISwitch *sw1 = [[UISwitch alloc] initWithFrame:CGRectMake(inner - 66, 8, 51, 31)];
    sw1.on = prefs.enabled;
    [sw1 addTarget:self action:@selector(switchEnabledChanged:) forControlEvents:UIControlEventValueChanged];
    [box1 addSubview:sw1];

    // Switch 2: Haptic
    UILabel *lbl2 = [[UILabel alloc] initWithFrame:CGRectMake(16, 64, inner - 100, 24)];
    lbl2.text = @"Rung phản hồi (Haptic)";
    lbl2.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [box1 addSubview:lbl2];
    
    UISwitch *sw2 = [[UISwitch alloc] initWithFrame:CGRectMake(inner - 66, 60, 51, 31)];
    sw2.on = prefs.hapticFeedback;
    [sw2 addTarget:self action:@selector(switchHapticChanged:) forControlEvents:UIControlEventValueChanged];
    [box1 addSubview:sw2];

    // Switch 3: Auto re-lock
    UILabel *lbl3 = [[UILabel alloc] initWithFrame:CGRectMake(16, 116, inner - 100, 24)];
    lbl3.text = @"Tự khoá lại khi về dọc";
    lbl3.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [box1 addSubview:lbl3];
    
    UISwitch *sw3 = [[UISwitch alloc] initWithFrame:CGRectMake(inner - 66, 112, 51, 31)];
    sw3.on = prefs.autoRelockOnPortrait;
    [sw3 addTarget:self action:@selector(switchRelockChanged:) forControlEvents:UIControlEventValueChanged];
    [box1 addSubview:sw3];

    [_content addSubview:box1];
    y += 182;

    // 3. Action Section
    UIButton *respringBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    respringBtn.frame = CGRectMake(x, y, inner, 48);
    respringBtn.backgroundColor = [UIColor colorWithRed:0.12 green:0.53 blue:0.90 alpha:1.0];
    respringBtn.layer.cornerRadius = 14;
    [respringBtn setTitle:@"Áp dụng & Respring" forState:UIControlStateNormal];
    [respringBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    respringBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [respringBtn addTarget:self action:@selector(respring) forControlEvents:UIControlEventTouchUpInside];
    [_content addSubview:respringBtn];
    y += 62;

    // 4. Donate Section
    UILabel *sec2 = [[UILabel alloc] initWithFrame:CGRectMake(x + 4, y, inner, 22)];
    sec2.text = @"ỦNG HỘ TÁC GIẢ (DONATE)";
    sec2.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    sec2.textColor = [UIColor secondaryLabelColor];
    [_content addSubview:sec2];
    y += 28;

    UIView *donCard = [self cardView];
    donCard.frame = CGRectMake(x, y, inner, 100);
    UILabel *dt = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, inner - 32, 76)];
    dt.numberOfLines = 4;
    dt.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    dt.text = @"Ngân hàng: MB Bank\nSố tài khoản: 0345140889\nChủ tài khoản: NGUYEN TIEN TRIEU\nCảm ơn anh em đã đồng hành & ủng hộ!";
    [donCard addSubview:dt];
    [_content addSubview:donCard];
    y += 112;

    UIButton *kofiBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    kofiBtn.frame = CGRectMake(x, y, inner, 44);
    if (@available(iOS 13.0, *)) kofiBtn.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    else kofiBtn.backgroundColor = [UIColor whiteColor];
    kofiBtn.layer.cornerRadius = 12;
    [kofiBtn setTitle:@"Ủng hộ qua Ko-fi (ko-fi.com/jinkennguyen)" forState:UIControlStateNormal];
    [kofiBtn addTarget:self action:@selector(openKofi) forControlEvents:UIControlEventTouchUpInside];
    [_content addSubview:kofiBtn];
    y += 52;

    UIButton *ppBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    ppBtn.frame = CGRectMake(x, y, inner, 44);
    if (@available(iOS 13.0, *)) ppBtn.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    else ppBtn.backgroundColor = [UIColor whiteColor];
    ppBtn.layer.cornerRadius = 12;
    [ppBtn setTitle:@"Ủng hộ qua PayPal (paypal.me/jinkennguyen)" forState:UIControlStateNormal];
    [ppBtn addTarget:self action:@selector(openPayPal) forControlEvents:UIControlEventTouchUpInside];
    [_content addSubview:ppBtn];
    y += 52;

    // Footer
    UILabel *foot = [[UILabel alloc] initWithFrame:CGRectMake(x, y, inner, 48)];
    foot.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    foot.numberOfLines = 2;
    foot.textAlignment = NSTextAlignmentCenter;
    foot.textColor = [UIColor tertiaryLabelColor];
    foot.text = @"OrientFlow © 2026 Jin Ken Nguyen - 1989.\nDesigned with high performance & liquid animation.";
    [_content addSubview:foot];
    y += 68;

    _content.frame = CGRectMake(0, 0, w, y);
    _scroll.contentSize = CGSizeMake(w, y);
}

- (void)saveKey:(NSString *)key value:(id)val {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)val, (CFStringRef)kOrientFlowPrefsDomain);
    CFPreferencesAppSynchronize((CFStringRef)kOrientFlowPrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(kOrientFlowPrefsNotification), NULL, NULL, YES);
}

- (void)switchEnabledChanged:(UISwitch *)sw {
    [self saveKey:@"enabled" value:@(sw.on)];
}

- (void)switchHapticChanged:(UISwitch *)sw {
    [self saveKey:@"hapticFeedback" value:@(sw.on)];
}

- (void)switchRelockChanged:(UISwitch *)sw {
    [self saveKey:@"autoRelockOnPortrait" value:@(sw.on)];
}

- (void)respring {
    pid_t pid;
    const char *args[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
}

- (void)openGitHub {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/tientrieu19892025/OrientFlow"] options:@{} completionHandler:nil];
}

- (void)openKofi {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://ko-fi.com/jinkennguyen"] options:@{} completionHandler:nil];
}

- (void)openPayPal {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://paypal.me/jinkennguyen"] options:@{} completionHandler:nil];
}

@end
