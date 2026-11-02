#import <UIKit/UIKit.h>
#import "InjectedMenuController.h"
#import "InjectedOverlayOwnership.h"
#import "InjectedWindowSelection.h"
#import "InjectedOverlayAttachment.h"
#include "InjectedStartupPolicy.h"

// ═══════════════════════════════════════════════════════════
// AUTH — dùng AuthSystem + TIZStorage từ Login.h
// ═══════════════════════════════════════════════════════════
#import "Login.h"

// ═══════════════════════════════════════════════════════════
// MizzeOverlayContainer — chặn touch xuyên qua vùng trống
// ═══════════════════════════════════════════════════════════
@interface MizzeOverlayContainer : UIView
@property(nonatomic,weak) UIView *contentView;
@end
@implementation MizzeOverlayContainer
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.contentView) ? nil : hit;
}
@end

// ═══════════════════════════════════════════════════════════
// LOGIN VIEW CONTROLLER (tách từ HomeViewController.mm)
// ═══════════════════════════════════════════════════════════
@interface MizzeLoginViewController : UIViewController {
    UITextField *keyTextField;
    UIButton *loginButton;
    UIButton *getFreeKeyButton;
    NSTimer *autoDismissTimer;
    UILabel *countdownLabel;
    int remainingSeconds;
}
@property (nonatomic, strong) void (^dismissCompletion)(BOOL success);
@end

@implementation MizzeLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];

    CGFloat cardWidth  = 320.0f;
    CGFloat cardHeight = 260.0f;
    CGRect cardFrame = CGRectMake((self.view.bounds.size.width  - cardWidth ) / 2.0f,
                                  (self.view.bounds.size.height - cardHeight) / 2.0f,
                                  cardWidth, cardHeight);

    UIView *cardView = [[UIView alloc] initWithFrame:cardFrame];
    cardView.backgroundColor = [UIColor colorWithRed:0.12 green:0.14 blue:0.18 alpha:0.95];
    cardView.layer.cornerRadius = 16.0f;
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOpacity = 0.5f;
    cardView.layer.shadowOffset = CGSizeMake(0, 4);
    cardView.layer.shadowRadius = 8.0f;
    cardView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                UIViewAutoresizingFlexibleRightMargin |
                                UIViewAutoresizingFlexibleTopMargin |
                                UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:cardView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 15, cardWidth - 30, 25)];
    titleLabel.text = @"XÁC THỰC BẢN QUYỀN";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:1.0];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [cardView addSubview:titleLabel];

    keyTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 50, cardWidth - 40, 40)];
    keyTextField.placeholder = @" Nhập mã Key...";
    keyTextField.layer.cornerRadius = 8.0f;
    keyTextField.layer.borderWidth  = 1.0f;
    keyTextField.layer.borderColor  = [UIColor colorWithWhite:0.3 alpha:0.5].CGColor;
    keyTextField.backgroundColor    = [UIColor colorWithRed:0.08 green:0.09 blue:0.12 alpha:1.0];
    keyTextField.textColor          = [UIColor whiteColor];
    keyTextField.font               = [UIFont systemFontOfSize:14];
    keyTextField.secureTextEntry    = YES;
    keyTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    keyTextField.autocorrectionType     = UITextAutocorrectionTypeNo;

    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
    keyTextField.leftView = paddingView;
    keyTextField.leftViewMode = UITextFieldViewModeAlways;
    [cardView addSubview:keyTextField];

    // Đọc key đã lưu
    NSString *savedKey = TIZStorage::loadKey();
    if (savedKey && savedKey.length > 0) {
        keyTextField.text = savedKey;
    }

    loginButton = [UIButton buttonWithType:UIButtonTypeCustom];
    loginButton.frame = CGRectMake(20, 100, cardWidth - 40, 38);
    [loginButton setTitle:@"ĐĂNG NHẬP" forState:UIControlStateNormal];
    [loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    loginButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.9 alpha:1.0];
    loginButton.layer.cornerRadius = 8.0f;
    loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [loginButton addTarget:self action:@selector(performLogin) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:loginButton];

    getFreeKeyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    getFreeKeyButton.frame = CGRectMake(20, 145, cardWidth - 40, 35);
    [getFreeKeyButton setTitle:@"LẤY KEY FREE" forState:UIControlStateNormal];
    [getFreeKeyButton setTitleColor:[UIColor colorWithRed:0.4 green:0.8 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
    getFreeKeyButton.backgroundColor = [UIColor clearColor];
    getFreeKeyButton.layer.cornerRadius = 8.0f;
    getFreeKeyButton.layer.borderWidth  = 1.0f;
    getFreeKeyButton.layer.borderColor  = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:0.8].CGColor;
    getFreeKeyButton.titleLabel.font = [UIFont systemFontOfSize:13];
    [getFreeKeyButton addTarget:self action:@selector(getFreeKey) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:getFreeKeyButton];

    countdownLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 190, cardWidth - 30, 20)];
    countdownLabel.textAlignment = NSTextAlignmentCenter;
    countdownLabel.textColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.2 alpha:1.0];
    countdownLabel.font = [UIFont systemFontOfSize:12];
    [cardView addSubview:countdownLabel];

    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 215, cardWidth - 30, 30)];
    statusLabel.text = @"Tự động thoát ứng dụng khi hết thời gian";
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.textColor = [UIColor lightGrayColor];
    statusLabel.font = [UIFont systemFontOfSize:10];
    statusLabel.numberOfLines = 1;
    [cardView addSubview:statusLabel];

    [self startAutoDismissTimer];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
}

- (void)dismissKeyboard { [keyTextField resignFirstResponder]; }

- (void)startAutoDismissTimer {
    remainingSeconds = 30;
    [self updateCountdownLabel];
    autoDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(updateTimer)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)updateTimer {
    remainingSeconds--;
    [self updateCountdownLabel];
    if (remainingSeconds <= 0) {
        [self cancelAutoDismissTimer];
        if (self.dismissCompletion) self.dismissCompletion(NO);
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)updateCountdownLabel {
    countdownLabel.text = [NSString stringWithFormat:@"⏱️ Tự động thoát sau: %ds", remainingSeconds];
}

- (void)resetTimer {
    remainingSeconds = 30;
    [self updateCountdownLabel];
    if (autoDismissTimer) [autoDismissTimer invalidate];
    autoDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(updateTimer)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message isError:(BOOL)isError {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
        if (!isError && self.dismissCompletion) {
            self.dismissCompletion(YES);
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performLogin {
    [self cancelAutoDismissTimer];

    NSString *key = keyTextField.text;
    if (key.length == 0) {
        [self showAlertWithTitle:@"Lỗi" message:@"Vui lòng nhập mã Key" isError:YES];
        [self resetTimer];
        return;
    }

    loginButton.enabled = NO;
    getFreeKeyButton.enabled = NO;
    [loginButton setTitle:@"ĐANG XÁC THỰC..." forState:UIControlStateNormal];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        std::string keyStr = [key UTF8String];
        std::string deviceID = AuthSystem::getDeviceID();
        std::string result = AuthSystem::DoLogin1(keyStr, deviceID);

        dispatch_async(dispatch_get_main_queue(), ^{
            self->loginButton.enabled = YES;
            self->getFreeKeyButton.enabled = YES;
            [self->loginButton setTitle:@"ĐĂNG NHẬP" forState:UIControlStateNormal];

            NSString *resultMsg = [NSString stringWithUTF8String:result.c_str()];

            if (AuthSystem::bValid) {
                [self cancelAutoDismissTimer];
                TIZStorage::saveKey(key);

                self->countdownLabel.text = @"✅ Xác thực thành công!";
                self->countdownLabel.textColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0];

                [self showAlertWithTitle:@"THÀNH CÔNG"
                                 message:[NSString stringWithFormat:@"%@\n\nUser: %s\nHạn dùng: %s\nCòn lại: %d ngày",
                                          resultMsg,
                                          AuthSystem::currentUser.c_str(),
                                          AuthSystem::expiryDate.c_str(),
                                          AuthSystem::remainingDays]
                                 isError:NO];
            } else {
                [self resetTimer];

                if ([resultMsg containsString:@"het han"] ||
                    [resultMsg containsString:@"khong hop le"] ||
                    [resultMsg containsString:@"that bai"]) {
                    TIZStorage::clearKey();
                }

                [self showAlertWithTitle:@"THẤT BẠI" message:resultMsg isError:YES];
            }
        });
    });
}

- (void)getFreeKey {
    [self resetTimer];
    NSURL *url = [NSURL URLWithString:@"https://lyngocdiem.online/keyios.php"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)cancelAutoDismissTimer {
    if (autoDismissTimer) {
        [autoDismissTimer invalidate];
        autoDismissTimer = nil;
    }
}

@end

// ═══════════════════════════════════════════════════════════
// STATE OVERLAY
// ═══════════════════════════════════════════════════════════
static BOOL setupPending = NO;
static NSUInteger setupAttempts = 0;
static const NSUInteger kMaxSetupAttempts = 60;
static InjectedStartup::Gate startupGate;
static void ScheduleInjectedOverlay(NSTimeInterval delay);

// ═══════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════
static UIWindow *MizzeActiveWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive &&
                scene.activationState != UISceneActivationStateForegroundInactive) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) return w;
            }
        }
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindow *w = ((UIWindowScene *)scene).windows.firstObject;
                if (w) return w;
            }
        }
        return nil;
    }
    return UIApplication.sharedApplication.keyWindow;
}

static UIViewController *MizzeTopViewController(void) {
    UIViewController *top = MizzeActiveWindow().rootViewController;
    if (!top) return nil;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

static void MizzePresentLogin(void (^completion)(BOOL success)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = MizzeTopViewController();
        if (!presenter) {
            if (completion) completion(NO);
            return;
        }
        if ([presenter isKindOfClass:[MizzeLoginViewController class]]) return;

        MizzeLoginViewController *vc = [[MizzeLoginViewController alloc] init];
        vc.dismissCompletion = completion;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:vc animated:YES completion:nil];
    });
}

// ═══════════════════════════════════════════════════════════
// STARTUP FLOW
// ═══════════════════════════════════════════════════════════
static void MizzeBeginStartupFlow(void) {
    NSString *savedKey = TIZStorage::loadKey();

    if (savedKey && savedKey.length > 0) {
        // Tự động xác thực ngầm
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            std::string keyStr  = [savedKey UTF8String];
            std::string devID   = AuthSystem::getDeviceID();
            std::string result  = AuthSystem::DoLogin1(keyStr, devID);

            dispatch_async(dispatch_get_main_queue(), ^{
                if (AuthSystem::bValid) {
                    [MizzeLoginViewController class]; // no-op
                    ScheduleInjectedOverlay(0.25);
                } else {
                    NSString *msg = [NSString stringWithUTF8String:result.c_str()];
                    if ([msg containsString:@"het han"] ||
                        [msg containsString:@"khong hop le"] ||
                        [msg containsString:@"that bai"]) {
                        TIZStorage::clearKey();
                    }
                    MizzePresentLogin(^(BOOL success) {
                        if (success && AuthSystem::bValid) {
                            ScheduleInjectedOverlay(0.25);
                        } else {
                            kill(getpid(), SIGKILL);
                        }
                    });
                }
            });
        });
    } else {
        MizzePresentLogin(^(BOOL success) {
            if (success && AuthSystem::bValid) {
                ScheduleInjectedOverlay(0.25);
            } else {
                kill(getpid(), SIGKILL);
            }
        });
    }
}

// ═══════════════════════════════════════════════════════════
// OVERLAY SETUP (đã sạch — không phụ thuộc APIClient)
// ═══════════════════════════════════════════════════════════
static void SetupInjectedOverlayMenu() {
    NSCAssert(NSThread.isMainThread, @"Overlay setup requires the main thread");
    UIApplication *app = UIApplication.sharedApplication;
    if (!app || MizzeOverlayOwner(app)) return;

    const NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    UIWindow *gameWindow = MizzeFindGameWindow(app);
    UIViewController *host = gameWindow.rootViewController;
    const BOOL attached = host.isViewLoaded && host.view.window == gameWindow &&
        !host.isBeingPresented && !host.isBeingDismissed && !host.transitionCoordinator;

    if (!startupGate.ready(app.applicationState == UIApplicationStateActive, attached,
        reinterpret_cast<uintptr_t>((__bridge void *)gameWindow),
        gameWindow.bounds.size.width,
        gameWindow.bounds.size.height, now)) {
        if (++setupAttempts < kMaxSetupAttempts) ScheduleInjectedOverlay(1.0);
        return;
    }

    MizzeOverlayContainer *overlay = nil;
    @try {
        overlay = [[MizzeOverlayContainer alloc] initWithFrame:host.view.bounds];
        overlay.backgroundColor = UIColor.clearColor;
        overlay.userInteractionEnabled = YES;
        if (!MizzeClaimOverlay(app, overlay)) return;

        InjectedMenuController *root = [InjectedMenuController new];
        root.gameWindow = gameWindow;
        overlay.contentView = root.view;

        if (!MizzeAttachChildOverlay(host, overlay, root)) {
            MizzeReleaseOverlay(app, overlay);
            if (++setupAttempts < kMaxSetupAttempts) ScheduleInjectedOverlay(2.0);
            return;
        }

        NSLog(@"[Mizze] Overlay ready after host activation");
    } @catch (NSException *exception) {
        [overlay removeFromSuperview];
        MizzeReleaseOverlay(app, overlay);
        if (++setupAttempts < kMaxSetupAttempts) ScheduleInjectedOverlay(2.0);
        NSLog(@"[Mizze] Overlay setup failed: %@", exception.name);
    }
}

static void ScheduleInjectedOverlay(NSTimeInterval delay) {
    if (setupPending) return;
    setupPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        setupPending = NO;
        SetupInjectedOverlayMenu();
    });
}

// ═══════════════════════════════════════════════════════════
// ENTRY POINT
// ═══════════════════════════════════════════════════════════
static void __attribute__((constructor)) StealthDylibEntryPoint() {
    // Loader callbacks chạy trước UIApplicationMain — chỉ enqueue.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            for (NSNotificationName name in @[UIApplicationDidFinishLaunchingNotification,
                                               UIApplicationDidBecomeActiveNotification,
                                               UIWindowDidBecomeKeyNotification]) {
                [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                                usingBlock:^(NSNotification *notification) {
                    setupAttempts = 0;
                    ScheduleInjectedOverlay(0.25);
                }];
            }

            // Nếu chưa có overlay và AuthSystem chưa valid → bắt đầu flow login
            if (!AuthSystem::bValid) {
                MizzeBeginStartupFlow();
            } else {
                ScheduleInjectedOverlay(0.25);
            }
        }
    });
}
