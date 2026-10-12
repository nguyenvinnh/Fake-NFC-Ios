#import <UIKit/UIKit.h>

// Floating button states
typedef NS_ENUM(NSInteger, FakeNFCFloatState) {
    FakeNFCFloatStateIdle = 0,
    FakeNFCFloatStateCountdown,
    FakeNFCFloatStateArmed,
    FakeNFCFloatStateInjecting,
    FakeNFCFloatStateDone
};

@interface FakeNFCFloatManager : NSObject

@property(nonatomic, strong, readonly) UIButton *floatButton;

+ (instancetype)sharedManager;

- (void)showFloatButton;
- (void)hideFloatButton;
- (void)setState:(FakeNFCFloatState)state label:(NSString *)label;

@end
