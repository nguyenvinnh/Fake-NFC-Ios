#import "FakeNFCViewController.h"
#import "NFCInjector.h"
#import "NFCMessageBuilder.h"
#import "FakeNFCFloatManager.h"

@interface FakeNFCViewController ()
@property(nonatomic, strong) UISegmentedControl *typeControl;
@property(nonatomic, strong) UITextView *inputView;
@property(nonatomic, strong) UIButton *delay5Btn;
@property(nonatomic, strong) UIButton *delay10Btn;
@property(nonatomic, strong) UIButton *armButton;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UITextView *logTextView;
@end

@implementation FakeNFCViewController

+ (void)hideUI {
  [[NSNotificationCenter defaultCenter]
      postNotificationName:@"FakeNFCHideUINotification"
                    object:nil];
}

+ (void)showUI {
  [[NSNotificationCenter defaultCenter]
      postNotificationName:@"FakeNFCShowUINotification"
                    object:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor systemBackgroundColor];
  self.title = @"Fake NFC";

  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
    initWithTitle:@"Đóng" style:UIBarButtonItemStylePlain
    target:self action:@selector(dismissSelf)];

  self.typeControl = [[UISegmentedControl alloc] initWithItems:@[ @"Text", @"Link" ]];
  self.typeControl.selectedSegmentIndex = 1;
  [self.typeControl addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];

  self.inputView = [[UITextView alloc] initWithFrame:CGRectZero];
  self.inputView.font = [UIFont systemFontOfSize:15];
  self.inputView.layer.borderWidth = 1;
  self.inputView.layer.borderColor = [[UIColor separatorColor] CGColor];
  self.inputView.layer.cornerRadius = 8;
  self.inputView.text = @"https://example.com";

  self.statusLabel = [[UILabel alloc] init];
  self.statusLabel.textAlignment = NSTextAlignmentCenter;
  self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
  self.statusLabel.textColor = [UIColor secondaryLabelColor];
  self.statusLabel.numberOfLines = 0;
  self.statusLabel.text = @"Sẵn sàng";

  // Nút chờ tự động
  self.armButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.armButton setTitle:@"🎯 Chờ app mở NFC rồi inject tự động" forState:UIControlStateNormal];
  self.armButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
  [self.armButton addTarget:self action:@selector(armTapped) forControlEvents:UIControlEventTouchUpInside];
  self.armButton.backgroundColor = [UIColor systemGreenColor];
  [self.armButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  self.armButton.layer.cornerRadius = 8;

  // Hàng 2 nút delay
  self.delay5Btn = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.delay5Btn setTitle:@"⏱ Gửi sau 5 giây" forState:UIControlStateNormal];
  self.delay5Btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
  [self.delay5Btn addTarget:self action:@selector(sendDelay5Tapped) forControlEvents:UIControlEventTouchUpInside];
  self.delay5Btn.backgroundColor = [UIColor systemBlueColor];
  [self.delay5Btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  self.delay5Btn.layer.cornerRadius = 8;

  self.delay10Btn = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.delay10Btn setTitle:@"⏱ Gửi sau 10 giây" forState:UIControlStateNormal];
  self.delay10Btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
  [self.delay10Btn addTarget:self action:@selector(sendDelay10Tapped) forControlEvents:UIControlEventTouchUpInside];
  self.delay10Btn.backgroundColor = [UIColor systemIndigoColor];
  [self.delay10Btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  self.delay10Btn.layer.cornerRadius = 8;

  UIStackView *delayRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.delay5Btn, self.delay10Btn]];
  delayRow.axis = UILayoutConstraintAxisHorizontal;
  delayRow.spacing = 8;
  delayRow.distribution = UIStackViewDistributionFillEqually;

  UIButton *sendNow = [UIButton buttonWithType:UIButtonTypeSystem];
  [sendNow setTitle:@"⚡️ Gửi ngay" forState:UIControlStateNormal];
  sendNow.titleLabel.font = [UIFont systemFontOfSize:13];
  [sendNow addTarget:self action:@selector(sendImmediateTapped) forControlEvents:UIControlEventTouchUpInside];
  sendNow.backgroundColor = [UIColor systemFillColor];
  sendNow.layer.cornerRadius = 8;

  // LOG HEADER
  UILabel *logTitle = [[UILabel alloc] init];
  logTitle.text = @"SYSTEM LOGS:";
  logTitle.font = [UIFont boldSystemFontOfSize:11];
  logTitle.textColor = [UIColor labelColor];

  UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [clearBtn setTitle:@"Xóa" forState:UIControlStateNormal];
  clearBtn.titleLabel.font = [UIFont systemFontOfSize:11];
  [clearBtn addTarget:self action:@selector(clearLogTapped) forControlEvents:UIControlEventTouchUpInside];

  UIStackView *logHeader = [[UIStackView alloc] initWithArrangedSubviews:@[logTitle, clearBtn]];
  logHeader.axis = UILayoutConstraintAxisHorizontal;
  logHeader.distribution = UIStackViewDistributionEqualSpacing;

  self.logTextView = [[UITextView alloc] initWithFrame:CGRectZero];
  self.logTextView.editable = NO;
  self.logTextView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
  self.logTextView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
  self.logTextView.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
  self.logTextView.layer.cornerRadius = 8;

  // Lấy toàn bộ log lịch sử đã lưu trữ trong injector
  self.logTextView.text = [[NFCInjector sharedInstance] allLogsString];

  UIStackView *stack = [[UIStackView alloc]
    initWithArrangedSubviews:@[ self.typeControl, self.inputView, self.armButton, delayRow, sendNow, self.statusLabel, logHeader, self.logTextView ]];
  stack.axis = UILayoutConstraintAxisVertical;
  stack.spacing = 8;
  stack.translatesAutoresizingMaskIntoConstraints = NO;

  [self.view addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
    [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
    [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
    [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
    [self.inputView.heightAnchor constraintEqualToConstant:60],
    [self.armButton.heightAnchor constraintEqualToConstant:42],
    [delayRow.heightAnchor constraintEqualToConstant:40],
    [sendNow.heightAnchor constraintEqualToConstant:34],
  ]];

  // Cuộn log xuống cuối
  if (self.logTextView.text.length > 0) {
    [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length - 1, 1)];
  }

  __weak typeof(self) weakSelf = self;
  [NFCInjector sharedInstance].onLog = ^(NSString *logText) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (!weakSelf.logTextView) return;
      NSString *newText = [weakSelf.logTextView.text stringByAppendingFormat:@"%@\n", logText];
      weakSelf.logTextView.text = newText;
      [weakSelf.logTextView scrollRangeToVisible:NSMakeRange(newText.length - 1, 1)];
    });
  };

  // Cập nhật trạng thái nút arm nếu đang armed
  if ([NFCInjector sharedInstance].isArmed) {
    [self.armButton setTitle:@"❌ Hủy chờ (đang armed...)" forState:UIControlStateNormal];
    self.armButton.backgroundColor = [UIColor systemOrangeColor];
    self.statusLabel.text = @"Đang chờ app gọi beginSession NFC...";
  }
}

- (void)typeChanged:(UISegmentedControl *)sender {
  if (sender.selectedSegmentIndex == 0) {
    if ([self.inputView.text isEqualToString:@"https://example.com"]) {
      self.inputView.text = @"Xin chao NFC";
    }
  } else {
    if ([self.inputView.text isEqualToString:@"Xin chao NFC"]) {
      self.inputView.text = @"https://example.com";
    }
  }
}

- (void)dismissSelf {
  [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearLogTapped {
  [[NFCInjector sharedInstance] clearLogs];
  self.logTextView.text = @"--- Log đã xóa ---\n";
}

- (void)sendWithDelay:(NSTimeInterval)seconds {
  NSError *error = nil;
  AFNFCInputType type = self.typeControl.selectedSegmentIndex == 0 ? AFNFCInputTypeText : AFNFCInputTypeLink;
  NFCNDEFMessage *message = [NFCMessageBuilder messageForType:type value:self.inputView.text error:&error];

  if (!message) {
    self.statusLabel.text = error.localizedDescription ?: @"Dữ liệu không hợp lệ!";
    return;
  }

  if (seconds > 0) {
    [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateCountdown label:[NSString stringWithFormat:@"%ds", (int)seconds]];

    __block NSInteger remaining = (NSInteger)seconds;
    [[NFCInjector sharedInstance] log:@"[TIMER] Đếm ngược %.0fs - Hãy mở app mục tiêu và bấm Scan/Read ngay!", seconds];
    self.statusLabel.text = [NSString stringWithFormat:@"Đang đếm ngược: %lds...", remaining];

    NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
      remaining--;
      dispatch_async(dispatch_get_main_queue(), ^{
        if (remaining > 0) {
          self.statusLabel.text = [NSString stringWithFormat:@"Đang đếm ngược: %lds...", remaining];
          [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateCountdown label:[NSString stringWithFormat:@"%lds", remaining]];
        } else {
          [timer invalidate];
          self.statusLabel.textColor = [UIColor systemGreenColor];
          self.statusLabel.text = @"Đang inject NFC...";
          [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateInjecting label:@"SEND"];
        }
      });
    }];
    [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
  }

  [[NFCInjector sharedInstance] injectMessage:message delay:seconds error:&error];

  // Đóng panel để người dùng thao tác trên app mục tiêu
  if (seconds > 0) {
    [self dismissSelf];
  }
}

- (void)sendDelay5Tapped  { [self sendWithDelay:5.0];  }
- (void)sendDelay10Tapped { [self sendWithDelay:10.0]; }
- (void)sendImmediateTapped { [self sendWithDelay:0.0]; }

- (void)armTapped {
  NFCInjector *injector = [NFCInjector sharedInstance];
  if (injector.isArmed) {
    [injector disarm];
    [self.armButton setTitle:@"🎯 Chờ app mở NFC rồi inject tự động" forState:UIControlStateNormal];
    self.armButton.backgroundColor = [UIColor systemGreenColor];
    self.statusLabel.text = @"Đã hủy chế độ chờ.";
    [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateIdle label:@"FAKE"];
    return;
  }

  NSError *error = nil;
  AFNFCInputType type = self.typeControl.selectedSegmentIndex == 0 ? AFNFCInputTypeText : AFNFCInputTypeLink;
  NFCNDEFMessage *message = [NFCMessageBuilder messageForType:type value:self.inputView.text error:&error];
  if (!message) {
    self.statusLabel.text = error.localizedDescription ?: @"Dữ liệu không hợp lệ!";
    return;
  }

  __weak typeof(self) weakSelf = self;
  [injector armWithMessage:message onSessionDetected:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      weakSelf.statusLabel.text = @"ĐÃ INJECT! App vừa quét NFC → đã nhận payload giả.";
      weakSelf.statusLabel.textColor = [UIColor systemGreenColor];
      [weakSelf.armButton setTitle:@"🎯 Chờ app mở NFC rồi inject tự động" forState:UIControlStateNormal];
      weakSelf.armButton.backgroundColor = [UIColor systemGreenColor];
      [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateDone label:@"DONE"];
    });
  }];

  [self.armButton setTitle:@"❌ Hủy chờ (đang armed...)" forState:UIControlStateNormal];
  self.armButton.backgroundColor = [UIColor systemOrangeColor];
  self.statusLabel.text = @"Đang chờ app gọi beginSession NFC...";
  [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateArmed label:@"WAIT"];

  // Đóng panel, icon nổi sẽ hiển thị WAIT màu xanh lá
  [self dismissSelf];
}

@end