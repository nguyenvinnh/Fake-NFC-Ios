#import "FakeNFCViewController.h"
#import "NFCInjector.h"
#import "NFCMessageBuilder.h"
#import "FakeNFCFloatManager.h"
#import "NFCTemplateManager.h"

// Chế độ gửi NFC
typedef NS_ENUM(NSInteger, FakeNFCSendMode) {
  FakeNFCSendModeImmediate = 0, // Gửi ngay
  FakeNFCSendModeDelay5,        // Sau 5 giây
  FakeNFCSendModeDelay10,       // Sau 10 giây
  FakeNFCSendModeAuto           // Tự động (chờ app mở NFC)
};

@interface FakeNFCViewController () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) UISegmentedControl *typeControl;
@property(nonatomic, strong) UITextView *inputView;
@property(nonatomic, strong) UIButton *modeButton;
@property(nonatomic, strong) UIButton *actionButton;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UITableView *templatesTableView;
@property(nonatomic, strong) UITextView *logTextView;
@property(nonatomic, assign) FakeNFCSendMode currentMode;
@property(nonatomic, strong) NSMutableArray<NFCTemplateModel *> *templates;
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

static NSString *const kFakeNFCSendModeKey = @"FakeNFC_SavedSendMode";

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor systemBackgroundColor];
  self.title = @"Giả Lập NFC";

  // Khôi phục chế độ đã lưu
  NSInteger savedMode = [[NSUserDefaults standardUserDefaults] integerForKey:kFakeNFCSendModeKey];
  if (savedMode >= 0 && savedMode <= 3) {
    self.currentMode = (FakeNFCSendMode)savedMode;
  } else {
    self.currentMode = FakeNFCSendModeImmediate;
  }

  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
    initWithTitle:@"Đóng" style:UIBarButtonItemStylePlain
    target:self action:@selector(dismissSelf)];

  // Nút Lưu Mẫu ở góc trên bên phải
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
    initWithTitle:@"Lưu Mẫu" style:UIBarButtonItemStyleDone
    target:self action:@selector(saveCurrentAsTemplateTapped)];

  // 1. Phân loại Text / Link
  self.typeControl = [[UISegmentedControl alloc] initWithItems:@[ @"Văn bản (Text)", @"Đường dẫn (Link)" ]];
  self.typeControl.selectedSegmentIndex = 1;
  [self.typeControl addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];

  // 2. Ô nhập nội dung
  self.inputView = [[UITextView alloc] initWithFrame:CGRectZero];
  self.inputView.font = [UIFont systemFontOfSize:14];
  self.inputView.layer.borderWidth = 1;
  self.inputView.layer.borderColor = [[UIColor separatorColor] CGColor];
  self.inputView.layer.cornerRadius = 8;
  self.inputView.text = @"https://genshin-impact.fandom.com/vi/wiki/Nhân_Vật";

  // 3. Menu chọn chế độ gửi
  self.modeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.modeButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
  self.modeButton.backgroundColor = [UIColor secondarySystemFillColor];
  self.modeButton.layer.cornerRadius = 8;
  [self updateModeButtonTitle];
  [self setupModeButtonMenu];

  // 4. Nút Hành Động Gửi
  self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
  self.actionButton.backgroundColor = [UIColor systemBlueColor];
  [self.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  self.actionButton.layer.cornerRadius = 8;
  [self updateActionButtonTitle];
  [self.actionButton addTarget:self action:@selector(actionButtonTapped) forControlEvents:UIControlEventTouchUpInside];

  UIStackView *controlRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.modeButton, self.actionButton]];
  controlRow.axis = UILayoutConstraintAxisHorizontal;
  controlRow.spacing = 8;
  controlRow.distribution = UIStackViewDistributionFillProportionally;

  // 5. Trạng thái hoạt động
  self.statusLabel = [[UILabel alloc] init];
  self.statusLabel.textAlignment = NSTextAlignmentCenter;
  self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
  self.statusLabel.textColor = [UIColor secondaryLabelColor];
  self.statusLabel.numberOfLines = 1;
  self.statusLabel.text = @"Sẵn sàng gửi NFC";

  // 6. Header Danh Sách Mẫu Đã Lưu
  UILabel *templatesHeaderTitle = [[UILabel alloc] init];
  templatesHeaderTitle.text = @"MẪU ĐÃ LƯU (Chạm để dùng, vuốt để xoá):";
  templatesHeaderTitle.font = [UIFont boldSystemFontOfSize:11];
  templatesHeaderTitle.textColor = [UIColor secondaryLabelColor];

  UIButton *addManualTemplateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [addManualTemplateBtn setTitle:@"Thêm mới" forState:UIControlStateNormal];
  addManualTemplateBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
  [addManualTemplateBtn addTarget:self action:@selector(addNewTemplateDialog) forControlEvents:UIControlEventTouchUpInside];

  UIStackView *templatesHeader = [[UIStackView alloc] initWithArrangedSubviews:@[templatesHeaderTitle, addManualTemplateBtn]];
  templatesHeader.axis = UILayoutConstraintAxisHorizontal;
  templatesHeader.distribution = UIStackViewDistributionEqualSpacing;

  // 7. Bảng danh sách mẫu
  self.templatesTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  self.templatesTableView.layer.cornerRadius = 8;
  self.templatesTableView.layer.borderWidth = 1;
  self.templatesTableView.layer.borderColor = [[UIColor separatorColor] CGColor];
  self.templatesTableView.delegate = self;
  self.templatesTableView.dataSource = self;
  self.templatesTableView.rowHeight = 36;

  // 8. Header Log
  UILabel *logTitle = [[UILabel alloc] init];
  logTitle.text = @"NHẬT KÝ HỆ THỐNG:";
  logTitle.font = [UIFont boldSystemFontOfSize:11];
  logTitle.textColor = [UIColor secondaryLabelColor];

  UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [clearBtn setTitle:@"Xoá nhật ký" forState:UIControlStateNormal];
  clearBtn.titleLabel.font = [UIFont systemFontOfSize:11];
  [clearBtn addTarget:self action:@selector(clearLogTapped) forControlEvents:UIControlEventTouchUpInside];

  UIStackView *logHeader = [[UIStackView alloc] initWithArrangedSubviews:@[logTitle, clearBtn]];
  logHeader.axis = UILayoutConstraintAxisHorizontal;
  logHeader.distribution = UIStackViewDistributionEqualSpacing;

  // 9. Khung log
  self.logTextView = [[UITextView alloc] initWithFrame:CGRectZero];
  self.logTextView.editable = NO;
  self.logTextView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
  self.logTextView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
  self.logTextView.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
  self.logTextView.layer.cornerRadius = 8;
  self.logTextView.text = [[NFCInjector sharedInstance] allLogsString];

  // Gom toàn bộ vào StackView dọc
  UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
    self.typeControl,
    self.inputView,
    controlRow,
    self.statusLabel,
    templatesHeader,
    self.templatesTableView,
    logHeader,
    self.logTextView
  ]];
  mainStack.axis = UILayoutConstraintAxisVertical;
  mainStack.spacing = 6;
  mainStack.translatesAutoresizingMaskIntoConstraints = NO;

  [self.view addSubview:mainStack];
  [NSLayoutConstraint activateConstraints:@[
    [mainStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
    [mainStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
    [mainStack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:6],
    [mainStack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-6],
    [self.typeControl.heightAnchor constraintEqualToConstant:30],
    [self.inputView.heightAnchor constraintEqualToConstant:50],
    [controlRow.heightAnchor constraintEqualToConstant:38],
    [self.modeButton.widthAnchor constraintEqualToConstant:150],
    [self.templatesTableView.heightAnchor constraintEqualToConstant:90],
  ]];

  [self reloadTemplates];

  // Tự động cuộn log xuống dòng mới nhất
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

  // Nếu đang armed từ trước
  if ([NFCInjector sharedInstance].isArmed) {
    self.currentMode = FakeNFCSendModeAuto;
    [self updateModeButtonTitle];
    [self.actionButton setTitle:@"Huỷ Chế Độ Chờ" forState:UIControlStateNormal];
    self.actionButton.backgroundColor = [UIColor systemOrangeColor];
    self.statusLabel.text = @"Đang chờ ứng dụng quét NFC...";
  }
}

#pragma mark - Chế độ Gửi & Menu

- (void)setupModeButtonMenu {
  if (@available(iOS 14.0, *)) {
    UIAction *actNow = [UIAction actionWithTitle:@"Gửi ngay" image:nil identifier:nil handler:^(__kindof UIAction *action) {
      [self setSendMode:FakeNFCSendModeImmediate];
    }];
    UIAction *act5s = [UIAction actionWithTitle:@"Gửi sau 5 giây" image:nil identifier:nil handler:^(__kindof UIAction *action) {
      [self setSendMode:FakeNFCSendModeDelay5];
    }];
    UIAction *act10s = [UIAction actionWithTitle:@"Gửi sau 10 giây" image:nil identifier:nil handler:^(__kindof UIAction *action) {
      [self setSendMode:FakeNFCSendModeDelay10];
    }];
    UIAction *actAuto = [UIAction actionWithTitle:@"Tự động khi mở NFC" image:nil identifier:nil handler:^(__kindof UIAction *action) {
      [self setSendMode:FakeNFCSendModeAuto];
    }];

    UIMenu *menu = [UIMenu menuWithTitle:@"Chọn chế độ gửi NFC" children:@[actNow, act5s, act10s, actAuto]];
    self.modeButton.menu = menu;
    self.modeButton.showsMenuAsPrimaryAction = YES;
  } else {
    [self.modeButton addTarget:self action:@selector(showModeActionSheet) forControlEvents:UIControlEventTouchUpInside];
  }
}

- (void)showModeActionSheet {
  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Chọn chế độ gửi NFC" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Gửi ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self setSendMode:FakeNFCSendModeImmediate];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Gửi sau 5 giây" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self setSendMode:FakeNFCSendModeDelay5];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Gửi sau 10 giây" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self setSendMode:FakeNFCSendModeDelay10];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Tự động khi mở NFC" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self setSendMode:FakeNFCSendModeAuto];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:sheet animated:YES completion:nil];
}

- (void)setSendMode:(FakeNFCSendMode)mode {
  self.currentMode = mode;
  [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kFakeNFCSendModeKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [self updateModeButtonTitle];
  [self updateActionButtonTitle];
}

- (void)updateModeButtonTitle {
  NSString *modeName = @"Gửi ngay";
  switch (self.currentMode) {
    case FakeNFCSendModeImmediate: modeName = @"Chế độ: Gửi ngay"; break;
    case FakeNFCSendModeDelay5:    modeName = @"Chế độ: Sau 5s"; break;
    case FakeNFCSendModeDelay10:   modeName = @"Chế độ: Sau 10s"; break;
    case FakeNFCSendModeAuto:      modeName = @"Chế độ: Tự động"; break;
  }
  [self.modeButton setTitle:modeName forState:UIControlStateNormal];
}

- (void)updateActionButtonTitle {
  if ([NFCInjector sharedInstance].isArmed) {
    [self.actionButton setTitle:@"Huỷ Chế Độ Chờ" forState:UIControlStateNormal];
    self.actionButton.backgroundColor = [UIColor systemOrangeColor];
    return;
  }

  NSString *btnTitle = @"Thực Hiện Gửi";
  UIColor *btnBg = [UIColor systemBlueColor];
  switch (self.currentMode) {
    case FakeNFCSendModeImmediate:
      btnTitle = @"Gửi Ngay";
      btnBg = [UIColor systemBlueColor];
      break;
    case FakeNFCSendModeDelay5:
      btnTitle = @"Bắt Đầu Hẹn Giờ 5s";
      btnBg = [UIColor systemIndigoColor];
      break;
    case FakeNFCSendModeDelay10:
      btnTitle = @"Bắt Đầu Hẹn Giờ 10s";
      btnBg = [UIColor systemIndigoColor];
      break;
    case FakeNFCSendModeAuto:
      btnTitle = @"Bật Chờ Quét Tự Động";
      btnBg = [UIColor systemGreenColor];
      break;
  }
  [self.actionButton setTitle:btnTitle forState:UIControlStateNormal];
  self.actionButton.backgroundColor = btnBg;
}

#pragma mark - Thực hiện gửi NFC

- (void)actionButtonTapped {
  if ([NFCInjector sharedInstance].isArmed) {
    // Đang chờ -> Huỷ chờ
    [[NFCInjector sharedInstance] disarm];
    [self updateActionButtonTitle];
    self.statusLabel.text = @"Đã huỷ chế độ chờ tự động.";
    [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateIdle label:@"NFC"];
    return;
  }

  switch (self.currentMode) {
    case FakeNFCSendModeImmediate:
      [self sendWithDelay:0.0];
      break;
    case FakeNFCSendModeDelay5:
      [self sendWithDelay:5.0];
      break;
    case FakeNFCSendModeDelay10:
      [self sendWithDelay:10.0];
      break;
    case FakeNFCSendModeAuto:
      [self armAutoNFC];
      break;
  }
}

- (void)sendWithDelay:(NSTimeInterval)seconds {
  NSError *error = nil;
  AFNFCInputType type = (self.typeControl.selectedSegmentIndex == 0) ? AFNFCInputTypeText : AFNFCInputTypeLink;
  NFCNDEFMessage *message = [NFCMessageBuilder messageForType:type value:self.inputView.text error:&error];

  if (!message) {
    self.statusLabel.text = error.localizedDescription ?: @"Dữ liệu không hợp lệ!";
    self.statusLabel.textColor = [UIColor systemRedColor];
    return;
  }

  if (seconds > 0) {
    [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateCountdown label:[NSString stringWithFormat:@"%ds", (int)seconds]];

    __block NSInteger remaining = (NSInteger)seconds;
    [[NFCInjector sharedInstance] log:@"[TIMER] Đếm ngược %.0fs - Hãy mở app mục tiêu và bấm Scan/Read ngay!", seconds];
    self.statusLabel.text = [NSString stringWithFormat:@"Đang đếm ngược: %lds...", remaining];
    self.statusLabel.textColor = [UIColor systemOrangeColor];

    NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
      remaining--;
      dispatch_async(dispatch_get_main_queue(), ^{
        if (remaining > 0) {
          self.statusLabel.text = [NSString stringWithFormat:@"Đang đếm ngược: %lds...", remaining];
          [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateCountdown label:[NSString stringWithFormat:@"%lds", remaining]];
        } else {
          [timer invalidate];
          self.statusLabel.textColor = [UIColor systemGreenColor];
          self.statusLabel.text = @"Đang đẩy dữ liệu NFC...";
          [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateInjecting label:@"SEND"];
        }
      });
    }];
    [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
  } else {
    self.statusLabel.text = @"Đã gửi trực tiếp tới phiên NFC.";
    self.statusLabel.textColor = [UIColor systemGreenColor];
  }

  [[NFCInjector sharedInstance] injectMessage:message delay:seconds error:&error];

  if (seconds > 0) {
    [self dismissSelf];
  }
}

- (void)armAutoNFC {
  NSError *error = nil;
  AFNFCInputType type = (self.typeControl.selectedSegmentIndex == 0) ? AFNFCInputTypeText : AFNFCInputTypeLink;
  NFCNDEFMessage *message = [NFCMessageBuilder messageForType:type value:self.inputView.text error:&error];

  if (!message) {
    self.statusLabel.text = error.localizedDescription ?: @"Dữ liệu không hợp lệ!";
    self.statusLabel.textColor = [UIColor systemRedColor];
    return;
  }

  __weak typeof(self) weakSelf = self;
  [[NFCInjector sharedInstance] armWithMessage:message onSessionDetected:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      weakSelf.statusLabel.text = @"ĐÃ TIÊM NFC! App vừa quét NFC đã nhận dữ liệu.";
      weakSelf.statusLabel.textColor = [UIColor systemGreenColor];
      [weakSelf updateActionButtonTitle];
      [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateDone label:@"DONE"];
    });
  }];

  [self.actionButton setTitle:@"Huỷ Chế Độ Chờ" forState:UIControlStateNormal];
  self.actionButton.backgroundColor = [UIColor systemOrangeColor];
  self.statusLabel.text = @"Đang chờ ứng dụng quét NFC...";
  self.statusLabel.textColor = [UIColor systemGreenColor];
  [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateArmed label:@"WAIT"];

  [self dismissSelf];
}

#pragma mark - Quản lý mẫu nhanh

- (void)reloadTemplates {
  self.templates = [[[NFCTemplateManager sharedManager] allTemplates] mutableCopy];
  [self.templatesTableView reloadData];
}

// Bấm nút "Lưu Mẫu" ở góc trên bên phải
- (void)saveCurrentAsTemplateTapped {
  NSString *currentVal = [self.inputView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (currentVal.length == 0) {
    self.statusLabel.text = @"Ô nội dung đang trống, không thể lưu!";
    self.statusLabel.textColor = [UIColor systemRedColor];
    return;
  }

  NSInteger curType = self.typeControl.selectedSegmentIndex;
  NSString *defaultTitle = (curType == 1) ? @"Đường dẫn mới" : @"Văn bản mới";

  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lưu Mẫu Nhanh"
                                                                 message:@"Nhập tên đại diện cho nội dung đang có ở khung nhập:"
                                                          preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    textField.placeholder = @"Tên mẫu (ví dụ: Trang chủ Wiki, Thẻ ID...)";
    textField.text = defaultTitle;
  }];

  UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Lưu Lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *title = alert.textFields[0].text;
    if (title.length == 0) title = defaultTitle;

    NFCTemplateModel *newModel = [[NFCTemplateModel alloc] initWithTitle:title value:currentVal type:curType];
    [[NFCTemplateManager sharedManager] addTemplate:newModel];
    [self reloadTemplates];

    self.statusLabel.text = [NSString stringWithFormat:@"Đã lưu mẫu: %@", title];
    self.statusLabel.textColor = [UIColor systemGreenColor];
  }];

  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil];

  [alert addAction:saveAction];
  [alert addAction:cancelAction];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)addNewTemplateDialog {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thêm Mẫu Mới" message:nil preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    textField.placeholder = @"Tên mẫu";
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    textField.placeholder = @"Nội dung (Link hoặc Văn bản)";
  }];

  __block NSInteger selType = 1; // Mặc định link
  UIAlertAction *typeToggle = [UIAlertAction actionWithTitle:@"Loại: Link (Chạm để đổi sang Text)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    selType = (selType == 1) ? 0 : 1;
    // mở lại alert với type mới
    NSString *t = alert.textFields[0].text;
    NSString *v = alert.textFields[1].text;
    [self showManualAddWithType:selType title:t value:v];
  }];

  UIAlertAction *saveAct = [UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *t = alert.textFields[0].text;
    NSString *v = alert.textFields[1].text;
    if (t.length == 0) t = @"Mẫu mới";
    NFCTemplateModel *m = [[NFCTemplateModel alloc] initWithTitle:t value:v type:selType];
    [[NFCTemplateManager sharedManager] addTemplate:m];
    [self reloadTemplates];
  }];

  UIAlertAction *cancelAct = [UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil];

  [alert addAction:typeToggle];
  [alert addAction:saveAct];
  [alert addAction:cancelAct];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showManualAddWithType:(NSInteger)type title:(NSString *)t value:(NSString *)v {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thêm Mẫu Mới" message:nil preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"Tên mẫu"; tf.text = t; }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"Nội dung"; tf.text = v; }];

  NSString *typeStr = (type == 0) ? @"Loại: Text (Chạm để đổi sang Link)" : @"Loại: Link (Chạm để đổi sang Text)";
  UIAlertAction *typeToggle = [UIAlertAction actionWithTitle:typeStr style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self showManualAddWithType:(type == 0 ? 1 : 0) title:alert.textFields[0].text value:alert.textFields[1].text];
  }];

  UIAlertAction *saveAct = [UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *title = alert.textFields[0].text ?: @"Mẫu mới";
    NSString *val = alert.textFields[1].text ?: @"";
    NFCTemplateModel *m = [[NFCTemplateModel alloc] initWithTitle:title value:val type:type];
    [[NFCTemplateManager sharedManager] addTemplate:m];
    [self reloadTemplates];
  }];

  [alert addAction:typeToggle];
  [alert addAction:saveAct];
  [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.templates.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cellId = @"QuickTemplateCell";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
  }

  NFCTemplateModel *model = self.templates[indexPath.row];
  NSString *typeBadge = (model.type == 0) ? @"[Text]" : @"[Link]";
  cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", typeBadge, model.title];
  cell.detailTextLabel.text = model.value;

  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  NFCTemplateModel *model = self.templates[indexPath.row];

  // Áp dụng mẫu đã chọn vào giao diện nhập
  self.typeControl.selectedSegmentIndex = model.type;
  self.inputView.text = model.value;
  self.statusLabel.text = [NSString stringWithFormat:@"Đã nạp mẫu: %@", model.title];
  self.statusLabel.textColor = [UIColor systemBlueColor];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    NFCTemplateModel *model = self.templates[indexPath.row];
    [[NFCTemplateManager sharedManager] deleteTemplateWithId:model.templateId];
    [self.templates removeObjectAtIndex:indexPath.row];
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    self.statusLabel.text = [NSString stringWithFormat:@"Đã xoá mẫu: %@", model.title];
  }
}

#pragma mark - Helper

- (void)typeChanged:(UISegmentedControl *)sender {
  if (sender.selectedSegmentIndex == 0) {
    if ([self.inputView.text containsString:@"genshin-impact.fandom.com"] || [self.inputView.text hasPrefix:@"http"]) {
      self.inputView.text = @"Xin chào thẻ NFC tiếng Việt";
    }
  } else {
    if ([self.inputView.text isEqualToString:@"Xin chào thẻ NFC tiếng Việt"]) {
      self.inputView.text = @"https://genshin-impact.fandom.com/vi/wiki/Nhân_Vật";
    }
  }
}

- (void)dismissSelf {
  [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearLogTapped {
  [[NFCInjector sharedInstance] clearLogs];
  self.logTextView.text = @"--- Nhật ký đã xoá ---\n";
}

@end