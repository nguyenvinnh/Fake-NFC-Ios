#import "FakeNFCViewController.h"
#import "NFCInjector.h"
#import "NFCMessageBuilder.h"
#import "FakeNFCFloatManager.h"
#import "NFCTemplateManager.h"
#import "NFCAdvancedConfigViewController.h"

// Chế độ gửi NFC
typedef NS_ENUM(NSInteger, FakeNFCSendMode) {
  FakeNFCSendModeImmediate = 0, // Gửi ngay
  FakeNFCSendModeDelay5,        // Sau 5 giây
  FakeNFCSendModeDelay10,       // Sau 10 giây
  FakeNFCSendModeAuto           // Tự động (chờ app mở NFC)
};

static NSString *const kFakeNFCSendModeKey = @"FakeNFC_SavedSendMode";

@interface FakeNFCViewController () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) UISegmentedControl *typeControl;
@property(nonatomic, strong) UITextView *inputView;
@property(nonatomic, strong) UIButton *advancedConfigButton;
@property(nonatomic, strong) UIButton *modeButton;
@property(nonatomic, strong) UIButton *actionButton;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UILabel *tagInfoBadgeLabel;
@property(nonatomic, strong) UITableView *templatesTableView;
@property(nonatomic, strong) UITextView *logTextView;
@property(nonatomic, assign) FakeNFCSendMode currentMode;
@property(nonatomic, strong) NSMutableArray<NFCTemplateModel *> *templates;
@property(nonatomic, strong) NFCTagConfig *currentTagConfig;
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
  self.title = @"Giả Lập NFC";

  // Cấu hình thẻ hiện tại (mặc định)
  self.currentTagConfig = [NFCInjector sharedInstance].currentTagConfig ?: [NFCTagConfig defaultConfig];

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

  // 1. Phân loại Text / Link / Historical Bytes (dùng chung 1 loại phân loại)
  self.typeControl = [[UISegmentedControl alloc] initWithItems:@[ @"Văn bản", @"Đường dẫn", @"Historical Bytes" ]];
  self.typeControl.selectedSegmentIndex = 1;
  [self.typeControl addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];

  // 2. Ô nhập nội dung
  self.inputView = [[UITextView alloc] initWithFrame:CGRectZero];
  self.inputView.font = [UIFont systemFontOfSize:14];
  self.inputView.layer.borderWidth = 1;
  self.inputView.layer.borderColor = [[UIColor separatorColor] CGColor];
  self.inputView.layer.cornerRadius = 8;
  self.inputView.text = @"https://genshin-impact.fandom.com/vi/wiki/Nhân_Vật";

  // 3. Nút Tuỳ Chỉnh Chuyên Sâu & Tag Badge info
  self.advancedConfigButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.advancedConfigButton setTitle:@"Tuỳ chỉnh chuyên sâu thẻ" forState:UIControlStateNormal];
  self.advancedConfigButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
  [self.advancedConfigButton setTitleColor:[UIColor systemIndigoColor] forState:UIControlStateNormal];
  self.advancedConfigButton.backgroundColor = [UIColor secondarySystemFillColor];
  self.advancedConfigButton.layer.cornerRadius = 6;
  [self.advancedConfigButton addTarget:self action:@selector(openAdvancedConfigTapped) forControlEvents:UIControlEventTouchUpInside];

  self.tagInfoBadgeLabel = [[UILabel alloc] init];
  self.tagInfoBadgeLabel.font = [UIFont systemFontOfSize:11];
  self.tagInfoBadgeLabel.textColor = [UIColor secondaryLabelColor];
  self.tagInfoBadgeLabel.textAlignment = NSTextAlignmentRight;
  [self updateTagInfoBadge];

  UIStackView *configRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.advancedConfigButton, self.tagInfoBadgeLabel]];
  configRow.axis = UILayoutConstraintAxisHorizontal;
  configRow.spacing = 8;
  configRow.distribution = UIStackViewDistributionFillProportionally;

  // 4. Menu chọn chế độ gửi & Nút Hành Động Gửi
  self.modeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.modeButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
  self.modeButton.backgroundColor = [UIColor secondarySystemFillColor];
  self.modeButton.layer.cornerRadius = 8;
  [self updateModeButtonTitle];
  [self setupModeButtonMenu];

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

  UIStackView *templatesHeader = [[UIStackView alloc] initWithArrangedSubviews:@[templatesHeaderTitle]];
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
    configRow,
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
    [self.inputView.heightAnchor constraintEqualToConstant:48],
    [configRow.heightAnchor constraintEqualToConstant:28],
    [self.advancedConfigButton.widthAnchor constraintEqualToConstant:180],
    [controlRow.heightAnchor constraintEqualToConstant:36],
    [self.modeButton.widthAnchor constraintEqualToConstant:150],
    [self.templatesTableView.heightAnchor constraintEqualToConstant:86],
  ]];

  [self reloadTemplates];

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

  if ([NFCInjector sharedInstance].isArmed) {
    self.currentMode = FakeNFCSendModeAuto;
    [self updateModeButtonTitle];
    [self.actionButton setTitle:@"Huỷ Chế Độ Chờ" forState:UIControlStateNormal];
    self.actionButton.backgroundColor = [UIColor systemOrangeColor];
    self.statusLabel.text = @"Đang chờ ứng dụng quét NFC...";
  }
}

- (void)updateTagInfoBadge {
  NSString *typeStr = self.currentTagConfig.tagType ?: @"Unknown";
  NSString *uidStr = self.currentTagConfig.serialNumber ?: @"Unknown";
  NSString *wStr = self.currentTagConfig.isWritable ? @"RW" : @"RO";
  self.tagInfoBadgeLabel.text = [NSString stringWithFormat:@"%@ | UID:%@ | %@", typeStr, uidStr, wStr];
}

#pragma mark - Tuỳ Chỉnh Chuyên Sâu

- (void)openAdvancedConfigTapped {
  __weak typeof(self) weakSelf = self;
  NSInteger currentDataType = self.typeControl.selectedSegmentIndex;
  NSString *currentContent  = self.inputView.text ?: @"";

  NFCAdvancedConfigViewController *vc = [[NFCAdvancedConfigViewController alloc]
      initWithConfig:self.currentTagConfig
             content:currentContent
            dataType:currentDataType
              onSave:^(NFCTagConfig *updatedConfig, NSString *content, NSInteger dataType) {
    // Đồng bộ cấu hình phần cứng
    weakSelf.currentTagConfig = updatedConfig;
    [NFCInjector sharedInstance].currentTagConfig = updatedConfig;
    [weakSelf updateTagInfoBadge];

    // Đồng bộ loại dữ liệu và nội dung về màn hình chính
    weakSelf.typeControl.selectedSegmentIndex = dataType;
    if (content.length > 0) {
      weakSelf.inputView.text = content;
    }

    weakSelf.statusLabel.text = [NSString stringWithFormat:@"Đã cập nhật: %@ | %@",
        updatedConfig.tagType,
        dataType == 0 ? @"Văn bản" : dataType == 1 ? @"Đường dẫn" : @"Historical Bytes"];
    weakSelf.statusLabel.textColor = [UIColor systemBlueColor];
  }];
  [self.navigationController pushViewController:vc animated:YES];
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
  AFNFCInputType type = (AFNFCInputType)self.typeControl.selectedSegmentIndex;
  NFCNDEFMessage *message = [NFCMessageBuilder messageForType:type value:self.inputView.text error:&error];

  if (!message) {
    self.statusLabel.text = error.localizedDescription ?: @"Dữ liệu không hợp lệ!";
    self.statusLabel.textColor = [UIColor systemRedColor];
    return;
  }

  // Nếu là Historical Bytes: ép isWritable = NO
  if (type == AFNFCInputTypeHistoricalBytes) {
    self.currentTagConfig.isWritable = NO;
    self.currentTagConfig.historicalBytesHex = self.inputView.text;
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

  [[NFCInjector sharedInstance] injectMessage:message config:self.currentTagConfig delay:seconds error:&error];

  if (seconds > 0) {
    [self dismissSelf];
  }
}

- (void)armAutoNFC {
  NSError *error = nil;
  AFNFCInputType type = (AFNFCInputType)self.typeControl.selectedSegmentIndex;
  NFCNDEFMessage *message = [NFCMessageBuilder messageForType:type value:self.inputView.text error:&error];

  if (!message) {
    self.statusLabel.text = error.localizedDescription ?: @"Dữ liệu không hợp lệ!";
    self.statusLabel.textColor = [UIColor systemRedColor];
    return;
  }

  if (type == AFNFCInputTypeHistoricalBytes) {
    self.currentTagConfig.isWritable = NO;
    self.currentTagConfig.historicalBytesHex = self.inputView.text;
  }

  __weak typeof(self) weakSelf = self;
  [[NFCInjector sharedInstance] armWithMessage:message config:self.currentTagConfig onSessionDetected:^{
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
// Chỉ hỏi tên — nội dung & loại lấy từ ô đang nhập, config luôn dùng mặc định
- (void)saveCurrentAsTemplateTapped {
  NSString *currentVal = [self.inputView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (currentVal.length == 0) {
    self.statusLabel.text = @"Ô nội dung đang trống, không thể lưu!";
    self.statusLabel.textColor = [UIColor systemRedColor];
    return;
  }

  NSInteger curType = self.typeControl.selectedSegmentIndex;
  NSString *defaultTitle = @"Mẫu mới";
  if (curType == 0) defaultTitle = @"Văn bản mới";
  else if (curType == 1) defaultTitle = @"Đường dẫn mới";
  else defaultTitle = @"Historical Bytes mới";

  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lưu Mẫu"
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = @"Tên mẫu";
    tf.text = defaultTitle;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
  }];

  UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *title = [alert.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length == 0) title = defaultTitle;

    // Luôn dùng config mặc định khi lưu từ màn hình cơ bản
    NFCTagConfig *cfg = [NFCTagConfig defaultConfig];
    if (curType == 2) {
      cfg.isWritable = NO;
      cfg.historicalBytesHex = currentVal;
    }

    NFCTemplateModel *newModel = [[NFCTemplateModel alloc] initWithTitle:title value:currentVal type:curType tagConfig:cfg];
    [[NFCTemplateManager sharedManager] addTemplate:newModel];
    [self reloadTemplates];

    self.statusLabel.text = [NSString stringWithFormat:@"Đã lưu mẫu: %@", title];
    self.statusLabel.textColor = [UIColor systemGreenColor];
  }];

  [alert addAction:saveAction];
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
    cell.textLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
  }

  NFCTemplateModel *model = self.templates[indexPath.row];
  NSString *typeBadge = @"[Link]";
  if (model.type == 0) typeBadge = @"[Text]";
  else if (model.type == 2) typeBadge = @"[Hist]";

  cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", typeBadge, model.title];
  cell.detailTextLabel.text = model.value;

  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  NFCTemplateModel *model = self.templates[indexPath.row];

  // Nạp loại dữ liệu & giá trị
  self.typeControl.selectedSegmentIndex = model.type;
  self.inputView.text = model.value;

  // Nạp cấu hình phần cứng tuỳ chỉnh của mẫu
  if (model.tagConfig) {
    self.currentTagConfig = [model.tagConfig copy];
    [NFCInjector sharedInstance].currentTagConfig = self.currentTagConfig;
  } else {
    // Mẫu cũ chỉ có thông tin cơ bản -> dùng giá trị mặc định
    self.currentTagConfig = [NFCTagConfig defaultConfig];
    if (model.type == 2) {
      self.currentTagConfig.isWritable = NO;
      self.currentTagConfig.historicalBytesHex = model.value;
    }
    [NFCInjector sharedInstance].currentTagConfig = self.currentTagConfig;
  }
  [self updateTagInfoBadge];

  self.statusLabel.text = [NSString stringWithFormat:@"Đã nạp mẫu: %@ (UID: %@)", model.title, self.currentTagConfig.serialNumber];
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
    if ([self.inputView.text containsString:@"genshin-impact.fandom.com"] || [self.inputView.text hasPrefix:@"http"] || [self.inputView.text containsString:@":"]) {
      self.inputView.text = @"Xin chào thẻ NFC tiếng Việt";
    }
  } else if (sender.selectedSegmentIndex == 1) {
    if ([self.inputView.text isEqualToString:@"Xin chào thẻ NFC tiếng Việt"] || [self.inputView.text containsString:@":"]) {
      self.inputView.text = @"https://genshin-impact.fandom.com/vi/wiki/Nhân_Vật";
    }
  } else {
    // Historical Bytes
    self.inputView.text = @"53:54:4D:73:69:6F";
    self.currentTagConfig.isWritable = NO;
    self.currentTagConfig.historicalBytesHex = self.inputView.text;
    [self updateTagInfoBadge];
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