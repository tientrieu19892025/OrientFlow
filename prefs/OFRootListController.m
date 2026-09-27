#import "OFRootListController.h"
#import "../include/OFPrefs.h"
#import "../include/OFLocalize.h"
#import <spawn.h>

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
        c.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
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
    hero.frame = CGRectMake(x, y, inner, 126);
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.colors = @[
        (id)[UIColor colorWithRed:0.10 green:0.48 blue:0.95 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.32 green:0.22 blue:0.88 alpha:1.0].CGColor
    ];
    grad.startPoint = CGPointMake(0, 0);
    grad.endPoint = CGPointMake(1, 1);
    grad.frame = CGRectMake(0, 0, inner, 126);
    grad.cornerRadius = 18;
    if (@available(iOS 13.0, *)) grad.cornerCurve = kCACornerCurveContinuous;
    [hero.layer insertSublayer:grad atIndex:0];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, inner - 40, 32)];
    title.text = @"OrientFlow";
    title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    [hero addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, inner - 40, 20)];
    sub.text = OFLoc(@"hero_sub");
    sub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    sub.textColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    [hero addSubview:sub];

    UILabel *meta = [[UILabel alloc] initWithFrame:CGRectMake(20, 74, inner - 40, 36)];
    meta.text = OFLoc(@"hero_desc");
    meta.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    meta.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    meta.numberOfLines = 2;
    [hero addSubview:meta];

    [_content addSubview:hero];
    y += 140;

    // 2. Section: General Settings
    UILabel *sec1 = [[UILabel alloc] initWithFrame:CGRectMake(x + 4, y, inner, 20)];
    sec1.text = OFLoc(@"sec_general");
    sec1.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    sec1.textColor = [UIColor secondaryLabelColor];
    [_content addSubview:sec1];
    y += 26;

    UIView *box1 = [self cardView];
    box1.frame = CGRectMake(x, y, inner, 216);

    // Switch 1: Enabled
    UILabel *lbl1 = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, inner - 90, 22)];
    lbl1.text = OFLoc(@"enabled");
    lbl1.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [box1 addSubview:lbl1];
    UILabel *sub1 = [[UILabel alloc] initWithFrame:CGRectMake(16, 34, inner - 90, 18)];
    sub1.text = OFLoc(@"enabled_sub");
    sub1.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    sub1.textColor = [UIColor secondaryLabelColor];
    [box1 addSubview:sub1];

    UISwitch *sw1 = [[UISwitch alloc] initWithFrame:CGRectMake(inner - 66, 16, 51, 31)];
    sw1.on = prefs.enabled;
    [sw1 addTarget:self action:@selector(switchEnabledChanged:) forControlEvents:UIControlEventValueChanged];
    [box1 addSubview:sw1];

    // Switch 2: Haptic
    UILabel *lbl2 = [[UILabel alloc] initWithFrame:CGRectMake(16, 78, inner - 90, 22)];
    lbl2.text = OFLoc(@"haptic");
    lbl2.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [box1 addSubview:lbl2];
    UILabel *sub2 = [[UILabel alloc] initWithFrame:CGRectMake(16, 100, inner - 90, 18)];
    sub2.text = OFLoc(@"haptic_sub");
    sub2.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    sub2.textColor = [UIColor secondaryLabelColor];
    [box1 addSubview:sub2];

    UISwitch *sw2 = [[UISwitch alloc] initWithFrame:CGRectMake(inner - 66, 82, 51, 31)];
    sw2.on = prefs.hapticFeedback;
    [sw2 addTarget:self action:@selector(switchHapticChanged:) forControlEvents:UIControlEventValueChanged];
    [box1 addSubview:sw2];

    // Switch 3: Auto re-lock
    UILabel *lbl3 = [[UILabel alloc] initWithFrame:CGRectMake(16, 146, inner - 90, 22)];
    lbl3.text = OFLoc(@"relock");
    lbl3.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [box1 addSubview:lbl3];
    UILabel *sub3 = [[UILabel alloc] initWithFrame:CGRectMake(16, 168, inner - 90, 36)];
    sub3.text = OFLoc(@"relock_sub");
    sub3.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    sub3.textColor = [UIColor secondaryLabelColor];
    sub3.numberOfLines = 2;
    [box1 addSubview:sub3];

    UISwitch *sw3 = [[UISwitch alloc] initWithFrame:CGRectMake(inner - 66, 152, 51, 31)];
    sw3.on = prefs.autoRelockOnPortrait;
    [sw3 addTarget:self action:@selector(switchRelockChanged:) forControlEvents:UIControlEventValueChanged];
    [box1 addSubview:sw3];

    [_content addSubview:box1];
    y += 228;

    // 3. Section: Appearance & Position
    UILabel *sec2 = [[UILabel alloc] initWithFrame:CGRectMake(x + 4, y, inner, 20)];
    sec2.text = OFLoc(@"sec_appearance");
    sec2.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    sec2.textColor = [UIColor secondaryLabelColor];
    [_content addSubview:sec2];
    y += 26;

    BOOL isCustomPos = (prefs.position == 3);
    CGFloat box2Height = isCustomPos ? 280 : 150;

    UIView *box2 = [self cardView];
    box2.frame = CGRectMake(x, y, inner, box2Height);

    // Duration Slider
    UILabel *durLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, inner - 32, 20)];
    durLbl.text = [NSString stringWithFormat:@"%@: %.1fs", OFLoc(@"duration_title"), prefs.duration];
    durLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [box2 addSubview:durLbl];

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(16, 36, inner - 32, 28)];
    slider.minimumValue = 1.5;
    slider.maximumValue = 8.0;
    slider.value = prefs.duration;
    [slider addTarget:self action:@selector(sliderDurationChanged:) forControlEvents:UIControlEventValueChanged];
    [box2 addSubview:slider];

    // Position Segment
    UILabel *posLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 76, inner - 32, 20)];
    posLbl.text = OFLoc(@"pos_title");
    posLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [box2 addSubview:posLbl];

    UISegmentedControl *posSeg = [[UISegmentedControl alloc] initWithItems:@[
        OFLoc(@"pos_br"), OFLoc(@"pos_bl"), OFLoc(@"pos_tr"), OFLoc(@"pos_custom")
    ]];
    posSeg.frame = CGRectMake(16, 102, inner - 32, 34);
    posSeg.selectedSegmentIndex = (prefs.position >= 0 && prefs.position <= 3) ? prefs.position : 0;
    [posSeg addTarget:self action:@selector(segmentPositionChanged:) forControlEvents:UIControlEventValueChanged];
    [box2 addSubview:posSeg];

    if (isCustomPos) {
        // Slider Offset X
        UILabel *xLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 146, inner - 32, 20)];
        xLbl.text = [NSString stringWithFormat:@"%@: %.0f%%", OFLoc(@"pos_offset_x"), prefs.offsetX];
        xLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        xLbl.tag = 101;
        [box2 addSubview:xLbl];

        UISlider *sliderX = [[UISlider alloc] initWithFrame:CGRectMake(16, 170, inner - 32, 28)];
        sliderX.minimumValue = 5.0;
        sliderX.maximumValue = 95.0;
        sliderX.value = prefs.offsetX;
        [sliderX addTarget:self action:@selector(sliderOffsetXChanged:) forControlEvents:UIControlEventValueChanged];
        [box2 addSubview:sliderX];

        // Slider Offset Y
        UILabel *yLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 210, inner - 32, 20)];
        yLbl.text = [NSString stringWithFormat:@"%@: %.0f%%", OFLoc(@"pos_offset_y"), prefs.offsetY];
        yLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        yLbl.tag = 102;
        [box2 addSubview:yLbl];

        UISlider *sliderY = [[UISlider alloc] initWithFrame:CGRectMake(16, 234, inner - 32, 28)];
        sliderY.minimumValue = 5.0;
        sliderY.maximumValue = 95.0;
        sliderY.value = prefs.offsetY;
        [sliderY addTarget:self action:@selector(sliderOffsetYChanged:) forControlEvents:UIControlEventValueChanged];
        [box2 addSubview:sliderY];
    }

    [_content addSubview:box2];
    y += (box2Height + 12);

    // 4. Section: Language Selection
    UILabel *secLang = [[UILabel alloc] initWithFrame:CGRectMake(x + 4, y, inner, 20)];
    secLang.text = OFLoc(@"sec_language");
    secLang.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    secLang.textColor = [UIColor secondaryLabelColor];
    [_content addSubview:secLang];
    y += 26;

    UIView *boxLang = [self cardView];
    boxLang.frame = CGRectMake(x, y, inner, 56);
    UISegmentedControl *langSeg = [[UISegmentedControl alloc] initWithItems:@[
        OFLoc(@"lang_auto"), OFLoc(@"lang_vi"), OFLoc(@"lang_en")
    ]];
    langSeg.frame = CGRectMake(16, 11, inner - 32, 34);
    langSeg.selectedSegmentIndex = (prefs.language >= 0 && prefs.language <= 2) ? prefs.language : 0;
    [langSeg addTarget:self action:@selector(segmentLanguageChanged:) forControlEvents:UIControlEventValueChanged];
    [boxLang addSubview:langSeg];
    [_content addSubview:boxLang];
    y += 68;

    // 5. System Actions
    UILabel *secAct = [[UILabel alloc] initWithFrame:CGRectMake(x + 4, y, inner, 20)];
    secAct.text = OFLoc(@"sec_actions");
    secAct.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    secAct.textColor = [UIColor secondaryLabelColor];
    [_content addSubview:secAct];
    y += 26;

    UIButton *respringBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    respringBtn.frame = CGRectMake(x, y, inner, 46);
    respringBtn.backgroundColor = [UIColor colorWithRed:0.10 green:0.48 blue:0.95 alpha:1.0];
    respringBtn.layer.cornerRadius = 14;
    [respringBtn setTitle:OFLoc(@"respring") forState:UIControlStateNormal];
    [respringBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    respringBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [respringBtn addTarget:self action:@selector(respring) forControlEvents:UIControlEventTouchUpInside];
    [_content addSubview:respringBtn];
    y += 58;

    // 6. Section: Donate
    UILabel *sec3 = [[UILabel alloc] initWithFrame:CGRectMake(x + 4, y, inner, 20)];
    sec3.text = OFLoc(@"sec_donate");
    sec3.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    sec3.textColor = [UIColor secondaryLabelColor];
    [_content addSubview:sec3];
    y += 26;

    UIView *donCard = [self cardView];
    donCard.frame = CGRectMake(x, y, inner, 96);
    UILabel *dt = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, inner - 32, 76)];
    dt.numberOfLines = 4;
    dt.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    dt.text = OFLoc(@"donate_info");
    [donCard addSubview:dt];
    [_content addSubview:donCard];
    y += 106;

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(x, y, inner, 42);
    if (@available(iOS 13.0, *)) copyBtn.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    else copyBtn.backgroundColor = [UIColor whiteColor];
    copyBtn.layer.cornerRadius = 12;
    [copyBtn setTitle:OFLoc(@"copy_account") forState:UIControlStateNormal];
    [copyBtn addTarget:self action:@selector(copyBankAccount) forControlEvents:UIControlEventTouchUpInside];
    [_content addSubview:copyBtn];
    y += 50;

    // 7. Section: International Support
    UILabel *secIntl = [[UILabel alloc] initWithFrame:CGRectMake(x + 4, y, inner, 20)];
    secIntl.text = OFLoc(@"sec_intl_donate");
    secIntl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    secIntl.textColor = [UIColor secondaryLabelColor];
    [_content addSubview:secIntl];
    y += 26;

    UIButton *kofiBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    kofiBtn.frame = CGRectMake(x, y, inner, 42);
    if (@available(iOS 13.0, *)) kofiBtn.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    else kofiBtn.backgroundColor = [UIColor whiteColor];
    kofiBtn.layer.cornerRadius = 12;
    [kofiBtn setTitle:@"Ko-fi (ko-fi.com/jinkennguyen)" forState:UIControlStateNormal];
    [kofiBtn addTarget:self action:@selector(openKofi) forControlEvents:UIControlEventTouchUpInside];
    [_content addSubview:kofiBtn];
    y += 48;

    UIButton *ppBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    ppBtn.frame = CGRectMake(x, y, inner, 42);
    if (@available(iOS 13.0, *)) ppBtn.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    else ppBtn.backgroundColor = [UIColor whiteColor];
    ppBtn.layer.cornerRadius = 12;
    [ppBtn setTitle:@"PayPal (paypal.me/jinkennguyen)" forState:UIControlStateNormal];
    [ppBtn addTarget:self action:@selector(openPayPal) forControlEvents:UIControlEventTouchUpInside];
    [_content addSubview:ppBtn];
    y += 48;

    UIButton *ghBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    ghBtn.frame = CGRectMake(x, y, inner, 42);
    if (@available(iOS 13.0, *)) ghBtn.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    else ghBtn.backgroundColor = [UIColor whiteColor];
    ghBtn.layer.cornerRadius = 12;
    [ghBtn setTitle:@"GitHub Repository (@tientrieu19892025)" forState:UIControlStateNormal];
    [ghBtn addTarget:self action:@selector(openGitHub) forControlEvents:UIControlEventTouchUpInside];
    [_content addSubview:ghBtn];
    y += 54;

    // 8. Footer
    UILabel *foot = [[UILabel alloc] initWithFrame:CGRectMake(x, y, inner, 46)];
    foot.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    foot.numberOfLines = 2;
    foot.textAlignment = NSTextAlignmentCenter;
    foot.textColor = [UIColor tertiaryLabelColor];
    foot.text = OFLoc(@"credit_footer");
    [_content addSubview:foot];
    y += 66;

    _content.frame = CGRectMake(0, 0, w, y);
    _scroll.contentSize = CGSizeMake(w, y);
}

- (void)switchEnabledChanged:(UISwitch *)sw {
    [[OFPrefs sharedInstance] saveKey:@"enabled" value:@(sw.on)];
}

- (void)switchHapticChanged:(UISwitch *)sw {
    [[OFPrefs sharedInstance] saveKey:@"hapticFeedback" value:@(sw.on)];
}

- (void)switchRelockChanged:(UISwitch *)sw {
    [[OFPrefs sharedInstance] saveKey:@"autoRelockOnPortrait" value:@(sw.on)];
}

- (void)sliderDurationChanged:(UISlider *)sl {
    [[OFPrefs sharedInstance] saveKey:@"duration" value:@(sl.value)];
}

- (void)segmentPositionChanged:(UISegmentedControl *)seg {
    [[OFPrefs sharedInstance] saveKey:@"position" value:@(seg.selectedSegmentIndex)];
    [self rebuild];
}

- (void)sliderOffsetXChanged:(UISlider *)sl {
    [[OFPrefs sharedInstance] saveKey:@"offsetX" value:@(sl.value)];
    UILabel *lbl = [self.view viewWithTag:101];
    if (lbl) {
        lbl.text = [NSString stringWithFormat:@"%@: %.0f%%", OFLoc(@"pos_offset_x"), sl.value];
    }
}

- (void)sliderOffsetYChanged:(UISlider *)sl {
    [[OFPrefs sharedInstance] saveKey:@"offsetY" value:@(sl.value)];
    UILabel *lbl = [self.view viewWithTag:102];
    if (lbl) {
        lbl.text = [NSString stringWithFormat:@"%@: %.0f%%", OFLoc(@"pos_offset_y"), sl.value];
    }
}

- (void)segmentLanguageChanged:(UISegmentedControl *)seg {
    [[OFPrefs sharedInstance] saveKey:@"language" value:@(seg.selectedSegmentIndex)];
    [self rebuild];
}

- (void)copyBankAccount {
    [UIPasteboard generalPasteboard].string = @"0345140889";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"OrientFlow" message:OFLoc(@"copy_done") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)respring {
    pid_t pid;
    // Try rootless /var/jb paths first, then rootful standard paths
    NSArray *candidates = @[
        @{@"bin": @"/var/jb/usr/bin/sbreload", @"args": @[@"sbreload"]},
        @{@"bin": @"/usr/bin/sbreload", @"args": @[@"sbreload"]},
        @{@"bin": @"/var/jb/usr/bin/killall", @"args": @[@"killall", @"-9", @"SpringBoard"]},
        @{@"bin": @"/usr/bin/killall", @"args": @[@"killall", @"-9", @"SpringBoard"]}
    ];

    for (NSDictionary *cmd in candidates) {
        NSString *bin = cmd[@"bin"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:bin]) {
            NSArray *argsArr = cmd[@"args"];
            const char **cargs = malloc(sizeof(char *) * (argsArr.count + 1));
            for (NSUInteger i = 0; i < argsArr.count; i++) {
                cargs[i] = [argsArr[i] UTF8String];
            }
            cargs[argsArr.count] = NULL;
            int ret = posix_spawn(&pid, [bin UTF8String], NULL, NULL, (char *const *)cargs, NULL);
            free(cargs);
            if (ret == 0) return;
        }
    }
    // Fallback standard posix_spawn
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
