#import <UIKit/UIKit.h>

@interface OFButtonWindow : UIWindow
+ (instancetype)sharedWindow;
- (void)showPromptWithOrientation:(UIInterfaceOrientation)orientation tapHandler:(void (^)(void))tapHandler;
- (void)hidePrompt;
@end
