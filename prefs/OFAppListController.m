#import "OFAppListController.h"
#import "../include/OFPrefs.h"
#import "../include/OFLocalize.h"
#import <objc/runtime.h>

@interface OFAppItem : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleID;
@end

@implementation OFAppItem
@end

@interface OFAppListController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSArray<OFAppItem *> *allApps;
@property (nonatomic, strong) NSArray<OFAppItem *> *filteredApps;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *selectedApps;
@end

@implementation OFAppListController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = OFLoc(@"app_list_title");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    OFPrefs *prefs = [OFPrefs sharedInstance];
    [prefs loadSettings];
    self.selectedApps = [prefs.selectedApps mutableCopy] ?: [NSMutableDictionary dictionary];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = OFLoc(@"search_apps");
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    
    UIBarButtonItem *selectAllBtn = [[UIBarButtonItem alloc] initWithTitle:OFLoc(@"select_all") style:UIBarButtonItemStylePlain target:self action:@selector(selectAllTapped)];
    UIBarButtonItem *clearBtn = [[UIBarButtonItem alloc] initWithTitle:OFLoc(@"deselect_all") style:UIBarButtonItemStylePlain target:self action:@selector(deselectAllTapped)];
    self.navigationItem.rightBarButtonItems = @[clearBtn, selectAllBtn];
    
    [self loadInstalledApps];
}

- (void)loadInstalledApps {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<OFAppItem *> *appsList = [NSMutableArray array];
        
        Class wsClass = objc_getClass("LSApplicationWorkspace");
        if (wsClass) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id ws = [wsClass performSelector:NSSelectorFromString(@"defaultWorkspace")];
            if (ws && [ws respondsToSelector:NSSelectorFromString(@"allInstalledApplications")]) {
                NSArray *proxies = [ws performSelector:NSSelectorFromString(@"allInstalledApplications")];
                for (id proxy in proxies) {
                    @try {
                        NSString *bundleID = [proxy respondsToSelector:NSSelectorFromString(@"applicationIdentifier")] ? 
                            [proxy performSelector:NSSelectorFromString(@"applicationIdentifier")] : nil;
                        NSString *name = [proxy respondsToSelector:NSSelectorFromString(@"localizedName")] ? 
                            [proxy performSelector:NSSelectorFromString(@"localizedName")] : nil;
                        
                        if (!bundleID || [bundleID length] == 0) continue;
                        // Skip internal daemons and webclips
                        if ([bundleID hasPrefix:@"com.apple.webapp"]) continue;
                        
                        OFAppItem *item = [[OFAppItem alloc] init];
                        item.bundleID = bundleID;
                        item.name = (name && [name length] > 0) ? name : bundleID;
                        [appsList addObject:item];
                    } @catch (NSException *ex) {}
                }
            }
            #pragma clang diagnostic pop
        }
        
        [appsList sortUsingComparator:^NSComparisonResult(OFAppItem *a, OFAppItem *b) {
            return [a.name localizedCaseInsensitiveCompare:b.name];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allApps = [appsList copy];
            self.filteredApps = self.allApps;
            [self.tableView reloadData];
        });
    });
}

- (void)selectAllTapped {
    NSArray<OFAppItem *> *targetList = self.isSearching ? self.filteredApps : self.allApps;
    for (OFAppItem *item in targetList) {
        self.selectedApps[item.bundleID] = @YES;
    }
    [[OFPrefs sharedInstance] saveKey:@"selectedApps" value:self.selectedApps];
    [self.tableView reloadData];
}

- (void)deselectAllTapped {
    NSArray<OFAppItem *> *targetList = self.isSearching ? self.filteredApps : self.allApps;
    for (OFAppItem *item in targetList) {
        [self.selectedApps removeObjectForKey:item.bundleID];
    }
    [[OFPrefs sharedInstance] saveKey:@"selectedApps" value:self.selectedApps];
    [self.tableView reloadData];
}

- (BOOL)isSearching {
    return self.searchController.isActive && self.searchController.searchBar.text.length > 0;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text lowercaseString];
    if (query.length == 0) {
        self.filteredApps = self.allApps;
    } else {
        NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(OFAppItem *item, NSDictionary *bindings) {
            return ([item.name.lowercaseString containsString:query] || [item.bundleID.lowercaseString containsString:query]);
        }];
        self.filteredApps = [self.allApps filteredArrayUsingPredicate:pred];
    }
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"OFAppCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UISwitch *sw = [[UISwitch alloc] init];
        [sw addTarget:self action:@selector(appSwitchToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    }
    
    OFAppItem *item = self.filteredApps[indexPath.row];
    cell.textLabel.text = item.name;
    cell.detailTextLabel.text = item.bundleID;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    
    UISwitch *sw = (UISwitch *)cell.accessoryView;
    sw.tag = indexPath.row;
    sw.on = [self.selectedApps[item.bundleID] boolValue];
    
    // Safely attempt to load icon
    @try {
        SEL iconSel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
        if ([UIImage respondsToSelector:iconSel]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            typedef UIImage *(*IconFunc)(id, SEL, NSString *, int, CGFloat);
            IconFunc func = (IconFunc)[UIImage methodForSelector:iconSel];
            cell.imageView.image = func([UIImage class], iconSel, item.bundleID, 0, [UIScreen mainScreen].scale);
            #pragma clang diagnostic pop
        }
    } @catch (NSException *e) {}
    
    return cell;
}

- (void)appSwitchToggled:(UISwitch *)sw {
    NSInteger row = sw.tag;
    if (row < self.filteredApps.count) {
        OFAppItem *item = self.filteredApps[row];
        if (sw.isOn) {
            self.selectedApps[item.bundleID] = @YES;
        } else {
            [self.selectedApps removeObjectForKey:item.bundleID];
        }
        [[OFPrefs sharedInstance] saveKey:@"selectedApps" value:self.selectedApps];
    }
}

@end
