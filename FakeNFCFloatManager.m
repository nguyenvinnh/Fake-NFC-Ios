#import "FakeNFCFloatManager.h"
#import "FakeNFCViewController.h"

// --------------------------------------------------
// UIWindow con có khả năng pass-through touch events hoàn hảo
// Khi không có modal: chỉ trả về view khi chạm trúng floatButton,
// còn lại trả về nil để toàn bộ tương tác truyền xuống app bên dưới.
// --------------------------------------------------
@interface FakeNFCPassThroughWindow : UIWindow
@end

@implementation FakeNFCPassThroughWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // 1. Nếu đang hiển thị modal cấu hình (FakeNFCViewController)
    if (self.rootViewController.presentedViewController != nil) {
        return [super hitTest:point withEvent:event];
    }

    // 2. Khi không hiển thị modal: CHỈ chạm vào nút tròn floatButton mới nhận
    UIButton *btn = [FakeNFCFloatManager sharedManager].floatButton;
    if (btn && !btn.hidden) {
        CGPoint ptInBtn = [btn convertPoint:point fromView:self];
        if ([btn pointInside:ptInBtn withEvent:event]) {
            return [btn hitTest:ptInBtn withEvent:event];
        }
    }

    // 3. Mọi điểm khác trên màn hình: trả về nil để xuyên thẳng xuống app
    return nil;
}

@end

// --------------------------------------------------
// Root view controller có background trong suốt
// --------------------------------------------------
@interface FakeNFCPassThroughVC : UIViewController
@end

@implementation FakeNFCPassThroughVC

- (void)loadView {
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = [UIColor clearColor];
    v.userInteractionEnabled = YES;
    self.view = v;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

@end

static FakeNFCFloatManager *gFloatManager = nil;

@interface FakeNFCFloatManager ()
@property(nonatomic, strong) FakeNFCPassThroughWindow *floatWindow;
@property(nonatomic, strong, readwrite) UIButton *floatButton;
@property(nonatomic, strong) UILabel *stateLabel;
@end

@implementation FakeNFCFloatManager

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gFloatManager = [[FakeNFCFloatManager alloc] init];
    });
    return gFloatManager;
}

- (void)showFloatButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatWindow) {
            self.floatWindow.hidden = NO;
            [self.floatWindow makeKeyAndVisible];
            return;
        }
        [self setupFloatWindow];
    });
}

- (void)hideFloatButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.floatWindow.hidden = YES;
    });
}

- (void)setupFloatWindow {
    UIWindowScene *scene = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive &&
                [s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
    }

    if (@available(iOS 13.0, *)) {
        if (scene) {
            self.floatWindow = [[FakeNFCPassThroughWindow alloc] initWithWindowScene:scene];
        }
    }
    if (!self.floatWindow) {
        self.floatWindow = [[FakeNFCPassThroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }

    self.floatWindow.windowLevel    = UIWindowLevelAlert + 999;
    self.floatWindow.backgroundColor = [UIColor clearColor];
    self.floatWindow.frame          = UIScreen.mainScreen.bounds;

    FakeNFCPassThroughVC *rootVC = [[FakeNFCPassThroughVC alloc] init];
    self.floatWindow.rootViewController = rootVC;

    // --- Floating circle button ---
    CGFloat btnSize = 58.0;
    CGFloat x = UIScreen.mainScreen.bounds.size.width - btnSize - 14;
    CGFloat y = UIScreen.mainScreen.bounds.size.height * 0.45;

    self.floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatButton.frame = CGRectMake(x, y, btnSize, btnSize);
    self.floatButton.layer.cornerRadius = btnSize / 2.0;
    self.floatButton.clipsToBounds = NO;
    self.floatButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.93];
    self.floatButton.layer.shadowColor   = [UIColor blackColor].CGColor;
    self.floatButton.layer.shadowRadius  = 8;
    self.floatButton.layer.shadowOpacity = 0.4;
    self.floatButton.layer.shadowOffset  = CGSizeMake(0, 3);

    // Label hiển thị trạng thái chữ (không dùng icon)
    self.stateLabel = [[UILabel alloc] initWithFrame:self.floatButton.bounds];
    self.stateLabel.text = @"NFC";
    self.stateLabel.font = [UIFont boldSystemFontOfSize:13];
    self.stateLabel.textColor = [UIColor whiteColor];
    self.stateLabel.textAlignment = NSTextAlignmentCenter;
    self.stateLabel.userInteractionEnabled = NO;
    [self.floatButton addSubview:self.stateLabel];

    [self.floatButton addTarget:self
                         action:@selector(floatButtonTapped)
               forControlEvents:UIControlEventTouchUpInside];

    // Kéo thả
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handlePan:)];
    [self.floatButton addGestureRecognizer:pan];

    [rootVC.view addSubview:self.floatButton];

    self.floatWindow.hidden = NO;
    [self.floatWindow makeKeyAndVisible];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:self.floatButton.superview];
    CGPoint c = self.floatButton.center;
    CGFloat half  = self.floatButton.bounds.size.width / 2.0;
    CGFloat maxX  = UIScreen.mainScreen.bounds.size.width  - half;
    CGFloat maxY  = UIScreen.mainScreen.bounds.size.height - half - 34;
    c.x = MAX(half,    MIN(maxX, c.x + t.x));
    c.y = MAX(half + 54, MIN(maxY, c.y + t.y));
    self.floatButton.center = c;
    [pan setTranslation:CGPointZero inView:self.floatButton.superview];
}

- (void)floatButtonTapped {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = self.floatWindow.rootViewController;
        if (rootVC.presentedViewController) {
            [rootVC dismissViewControllerAnimated:YES completion:nil];
            return;
        }
        FakeNFCViewController *vc = [[FakeNFCViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc]
            initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
        [rootVC presentViewController:nav animated:YES completion:nil];
    });
}

- (void)setState:(FakeNFCFloatState)state label:(NSString *)label {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (label) {
            self.stateLabel.text = label;
        }

        UIColor *color;
        BOOL resetAfterDelay = NO;
        switch (state) {
            case FakeNFCFloatStateIdle:
                color = [UIColor colorWithRed:0.0  green:0.48 blue:1.0  alpha:0.93];
                break;
            case FakeNFCFloatStateCountdown:
                color = [UIColor colorWithRed:1.0  green:0.58 blue:0.0  alpha:0.93];
                break;
            case FakeNFCFloatStateArmed:
                color = [UIColor colorWithRed:0.2  green:0.78 blue:0.35 alpha:0.93];
                break;
            case FakeNFCFloatStateInjecting:
                color = [UIColor colorWithRed:0.69 green:0.32 blue:0.87 alpha:0.93];
                break;
            case FakeNFCFloatStateDone:
                color = [UIColor colorWithRed:0.1  green:0.8  blue:0.4  alpha:0.93];
                resetAfterDelay = YES;
                break;
            default:
                color = [UIColor systemBlueColor];
                break;
        }

        [UIView animateWithDuration:0.25 animations:^{
            self.floatButton.backgroundColor = color;
        }];

        if (resetAfterDelay) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self setState:FakeNFCFloatStateIdle label:@"NFC"];
            });
        }
    });
}

@end
