#import "NFCAdvancedConfigViewController.h"

// Tên label và placeholder theo từng loại dữ liệu
static NSString * const kContentLabelText[3] = {
    @"NỘI DUNG VĂN BẢN:",
    @"ĐƯỜNG DẪN (URL):",
    @"HISTORICAL BYTES (HEX):"
};
static NSString * const kContentHintText[3] = {
    @"Nhập nội dung văn bản (hỗ trợ tiếng Việt có dấu)",
    @"Nhập đường dẫn, ví dụ: https://example.com/vi/nhân-vật",
    @"Nhập chuỗi hex phân cách bởi dấu ':', ví dụ: 53:54:4D:73"
};
static NSString * const kContentPlaceholder[3] = {
    @"Ví dụ: Xin chào thẻ NFC tiếng Việt",
    @"Ví dụ: https://genshin-impact.fandom.com/vi/wiki/Nhân_Vật",
    @"Ví dụ: 53:54:4D:73:69:6F"
};

@interface NFCAdvancedConfigViewController () <UITextFieldDelegate, UIScrollViewDelegate>
@property(nonatomic, strong) UIScrollView   *scrollView;
@property(nonatomic, strong) UITextField    *tagTypeField;
@property(nonatomic, strong) UITextField    *technologyField;
@property(nonatomic, strong) UITextField    *serialField;
// Ô nhập nội dung — thích ứng theo loại dữ liệu
@property(nonatomic, strong) UITextField    *contentField;
@property(nonatomic, strong) UILabel        *contentTitleLabel;
@property(nonatomic, strong) UILabel        *contentHintLabel;
// Writable
@property(nonatomic, strong) UISwitch       *writableSwitch;
@property(nonatomic, strong) UILabel        *writableHintLabel;
@property(nonatomic, strong) UIView         *writableRow;
// Segment chọn loại dữ liệu
@property(nonatomic, strong) UISegmentedControl *dataTypeControl;
@property(nonatomic, assign) NSInteger       currentDataType;
// Nội dung ban đầu từ màn chính
@property(nonatomic, copy)   NSString       *initialContent;
@end

@implementation NFCAdvancedConfigViewController

- (instancetype)initWithConfig:(NFCTagConfig *)config
                       content:(NSString *)content
                      dataType:(NSInteger)dataType
                        onSave:(NFCTagConfigSaveBlock)onSave {
    self = [super init];
    if (self) {
        _config          = config ? [config copy] : [NFCTagConfig defaultConfig];
        _initialContent  = content ?: @"";
        _currentDataType = dataType;
        _onSave          = [onSave copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tuỳ Chỉnh Thẻ Chuyên Sâu";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Lưu" style:UIBarButtonItemStyleDone
        target:self action:@selector(saveTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Đóng" style:UIBarButtonItemStylePlain
        target:self action:@selector(closeTapped)];

    // ── ScrollView (autolayout — tránh lỗi bàn phím) ──────────────────────
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIView *cv = [[UIView alloc] init];
    cv.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:cv];
    [NSLayoutConstraint activateConstraints:@[
        [cv.topAnchor      constraintEqualToAnchor:self.scrollView.topAnchor],
        [cv.leadingAnchor  constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [cv.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [cv.bottomAnchor   constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [cv.widthAnchor    constraintEqualToAnchor:self.scrollView.widthAnchor],
    ]];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis    = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor      constraintEqualToAnchor:cv.topAnchor      constant:16],
        [stack.leadingAnchor  constraintEqualToAnchor:cv.leadingAnchor  constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-16],
        [stack.bottomAnchor   constraintEqualToAnchor:cv.bottomAnchor   constant:-30],
    ]];

    // ── A. Loại dữ liệu NFC ───────────────────────────────────────────────
    [stack addArrangedSubview:[self sectionLabel:@"LOẠI DỮ LIỆU NFC:"
                                            hint:@"Chọn để ô nội dung bên dưới phù hợp với kiểu nhập"]];
    self.dataTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"Văn bản", @"Đường dẫn", @"Historical Bytes"]];
    self.dataTypeControl.selectedSegmentIndex = self.currentDataType;
    [self.dataTypeControl addTarget:self action:@selector(dataTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:self.dataTypeControl];

    // ── B. Ô nhập nội dung (thích ứng theo loại) ─────────────────────────
    self.contentTitleLabel = [UILabel new];
    self.contentTitleLabel.font = [UIFont boldSystemFontOfSize:12];
    self.contentTitleLabel.textColor = [UIColor labelColor];

    self.contentHintLabel = [UILabel new];
    self.contentHintLabel.font = [UIFont systemFontOfSize:11];
    self.contentHintLabel.textColor = [UIColor secondaryLabelColor];
    self.contentHintLabel.numberOfLines = 0;

    UIStackView *contentLabelStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.contentTitleLabel, self.contentHintLabel]];
    contentLabelStack.axis = UILayoutConstraintAxisVertical;
    contentLabelStack.spacing = 2;
    [stack addArrangedSubview:contentLabelStack];

    self.contentField = [self makeTextField:@""];
    self.contentField.delegate = self;
    self.contentField.text = self.initialContent;
    [stack addArrangedSubview:self.contentField];

    // Áp dụng cấu hình ô nhập ngay từ đầu
    [self applyContentFieldStyle:self.currentDataType];

    // ── C. Loại thẻ (Tag Type) ────────────────────────────────────────────
    [stack addArrangedSubview:[self sectionLabel:@"LOẠI THẺ (TAG TYPE):"
                                            hint:@"Ví dụ: ISO 14443-3A, Mifare Ultralight, ISO-DEP..."]];
    self.tagTypeField = [self makeTextField:@"Loại thẻ (để trống sẽ là Unknown)"];
    self.tagTypeField.delegate = self;
    self.tagTypeField.text = [self.config.tagType isEqualToString:@"Unknown"] ? @"" : self.config.tagType;
    [stack addArrangedSubview:self.tagTypeField];
    [stack addArrangedSubview:[self createPresetButtons]];

    // ── D. Công nghệ ──────────────────────────────────────────────────────
    [stack addArrangedSubview:[self sectionLabel:@"CÔNG NGHỆ (TECHNOLOGIES):"
                                            hint:@"Ví dụ: Type A, Type B, Type F, ISO-DEP..."]];
    self.technologyField = [self makeTextField:@"Công nghệ thẻ (để trống sẽ là Unknown)"];
    self.technologyField.delegate = self;
    self.technologyField.text = [self.config.technology isEqualToString:@"Unknown"] ? @"" : self.config.technology;
    [stack addArrangedSubview:self.technologyField];

    // ── E. Số Serial / UID ────────────────────────────────────────────────
    [stack addArrangedSubview:[self sectionLabel:@"SỐ SERIAL THẺ (SERIAL NUMBER / UID):"
                                            hint:@"Định dạng Hex: 04:12:34:56:78:9A:BC hoặc 1A:2B:3C:4D"]];
    self.serialField = [self makeTextField:@"Số Serial thẻ (để trống sẽ là Unknown)"];
    self.serialField.delegate = self;
    self.serialField.text = [self.config.serialNumber isEqualToString:@"Unknown"] ? @"" : self.config.serialNumber;
    [stack addArrangedSubview:self.serialField];

    UIButton *randBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [randBtn setTitle:@"Tạo ngẫu nhiên Serial 7-byte" forState:UIControlStateNormal];
    randBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [randBtn addTarget:self action:@selector(randomSerialTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:randBtn];

    // ── F. Writable ───────────────────────────────────────────────────────
    self.writableRow = [[UIView alloc] init];
    UILabel *wLabel = [[UILabel alloc] init];
    wLabel.text = @"Cho phép ghi (Writable):";
    wLabel.font = [UIFont boldSystemFontOfSize:14];
    wLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.writableSwitch = [[UISwitch alloc] init];
    self.writableSwitch.on = self.config.isWritable;
    self.writableSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.writableSwitch addTarget:self action:@selector(writableChanged:) forControlEvents:UIControlEventValueChanged];

    [self.writableRow addSubview:wLabel];
    [self.writableRow addSubview:self.writableSwitch];
    [NSLayoutConstraint activateConstraints:@[
        [wLabel.leadingAnchor             constraintEqualToAnchor:self.writableRow.leadingAnchor],
        [wLabel.centerYAnchor             constraintEqualToAnchor:self.writableRow.centerYAnchor],
        [self.writableSwitch.trailingAnchor constraintEqualToAnchor:self.writableRow.trailingAnchor],
        [self.writableSwitch.centerYAnchor  constraintEqualToAnchor:self.writableRow.centerYAnchor],
        [self.writableRow.heightAnchor    constraintEqualToConstant:36],
    ]];
    [stack addArrangedSubview:self.writableRow];

    self.writableHintLabel = [[UILabel alloc] init];
    self.writableHintLabel.font = [UIFont systemFontOfSize:11];
    self.writableHintLabel.textColor = [UIColor secondaryLabelColor];
    self.writableHintLabel.numberOfLines = 0;
    [stack addArrangedSubview:self.writableHintLabel];

    // Áp trạng thái writable ban đầu
    [self applyWritableState:self.currentDataType];

    // ── G. Đặt lại ───────────────────────────────────────────────────────
    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [resetBtn setTitle:@"Đặt lại về giá trị mặc định" forState:UIControlStateNormal];
    [resetBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    resetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [resetBtn addTarget:self action:@selector(resetDefaultTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:resetBtn];

    // ── Keyboard ──────────────────────────────────────────────────────────
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)n {
    CGRect kb = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval dur = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [n.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
    CGFloat inset = kb.size.height - self.view.safeAreaInsets.bottom;
    [UIView animateWithDuration:dur delay:0 options:curve animations:^{
        self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, inset, 0);
        self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset;
    } completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)n {
    NSTimeInterval dur = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [n.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
    [UIView animateWithDuration:dur delay:0 options:curve animations:^{
        self.scrollView.contentInset = UIEdgeInsetsZero;
        self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
    } completion:nil];
}

- (void)dismissKeyboard { [self.view endEditing:YES]; }

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    [tf resignFirstResponder];
    return YES;
}

#pragma mark - Data Type

- (void)dataTypeChanged:(UISegmentedControl *)sender {
    // Lưu nội dung hiện tại trước khi chuyển
    NSString *currentText = self.contentField.text ?: @"";

    self.currentDataType = sender.selectedSegmentIndex;
    [self applyContentFieldStyle:self.currentDataType];
    [self applyWritableState:self.currentDataType];

    // Nếu ô trống thì gợi ý placeholder theo loại mới
    if (currentText.length == 0) {
        self.contentField.text = @"";
    }
}

/**
 * Cập nhật label, hint, keyboard type và các thuộc tính bàn phím của ô nội dung
 * tùy theo loại dữ liệu đang chọn.
 */
- (void)applyContentFieldStyle:(NSInteger)type {
    self.contentTitleLabel.text = kContentLabelText[type];
    self.contentHintLabel.text  = kContentHintText[type];
    self.contentField.placeholder = kContentPlaceholder[type];

    if (type == 0) {
        // Văn bản: bàn phím mặc định, cho phép gõ thoải mái có dấu
        self.contentField.keyboardType          = UIKeyboardTypeDefault;
        self.contentField.autocorrectionType    = UITextAutocorrectionTypeDefault;
        self.contentField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        self.contentField.spellCheckingType     = UITextSpellCheckingTypeDefault;
        self.contentField.smartDashesType       = UITextSmartDashesTypeDefault;
        self.contentField.smartQuotesType       = UITextSmartQuotesTypeDefault;
        self.contentField.smartInsertDeleteType  = UITextSmartInsertDeleteTypeDefault;
    } else if (type == 1) {
        // Đường dẫn: bàn phím URL, tắt autocorrect để không sửa URL có dấu
        self.contentField.keyboardType          = UIKeyboardTypeURL;
        self.contentField.autocorrectionType    = UITextAutocorrectionTypeNo;
        self.contentField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.contentField.spellCheckingType     = UITextSpellCheckingTypeNo;
        self.contentField.smartDashesType       = UITextSmartDashesTypeNo;
        self.contentField.smartQuotesType       = UITextSmartQuotesTypeNo;
        self.contentField.smartInsertDeleteType  = UITextSmartInsertDeleteTypeNo;
    } else {
        // Historical Bytes: chỉ nhập hex, tắt hết tính năng thông minh
        self.contentField.keyboardType          = UIKeyboardTypeASCIICapable;
        self.contentField.autocorrectionType    = UITextAutocorrectionTypeNo;
        self.contentField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.contentField.spellCheckingType     = UITextSpellCheckingTypeNo;
        self.contentField.smartDashesType       = UITextSmartDashesTypeNo;
        self.contentField.smartQuotesType       = UITextSmartQuotesTypeNo;
        self.contentField.smartInsertDeleteType  = UITextSmartInsertDeleteTypeNo;
    }
    // Reload input views để iOS áp dụng bàn phím mới ngay
    [self.contentField reloadInputViews];
}

- (void)applyWritableState:(NSInteger)type {
    BOOL isHist = (type == 2);
    self.writableSwitch.enabled = !isHist;
    self.writableRow.alpha = isHist ? 0.4 : 1.0;
    if (isHist) {
        self.writableSwitch.on = NO;
        self.writableHintLabel.text = @"Historical Bytes không hỗ trợ ghi — luôn ở chế độ ReadOnly";
    } else {
        self.writableSwitch.on = self.config.isWritable;
        self.writableHintLabel.text = self.writableSwitch.on
            ? @"Thẻ đang ở chế độ ReadWrite (Có thể đọc và ghi đè)"
            : @"Thẻ đang ở chế độ ReadOnly (Chỉ đọc, không cho phép ghi)";
    }
}

#pragma mark - UI Builders

- (UIView *)sectionLabel:(NSString *)title hint:(NSString *)hint {
    UILabel *t = [UILabel new]; t.text = title; t.font = [UIFont boldSystemFontOfSize:12]; t.textColor = [UIColor labelColor];
    UILabel *h = [UILabel new]; h.text = hint;  h.font = [UIFont systemFontOfSize:11];    h.textColor = [UIColor secondaryLabelColor]; h.numberOfLines = 0;
    UIStackView *v = [[UIStackView alloc] initWithArrangedSubviews:@[t, h]];
    v.axis = UILayoutConstraintAxisVertical; v.spacing = 2;
    UIView *wrap = [UIView new]; v.translatesAutoresizingMaskIntoConstraints = NO;
    [wrap addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:wrap.topAnchor],
        [v.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor],
        [v.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],
    ]];
    return wrap;
}

/**
 * Tạo UITextField với các thuộc tính cơ bản (các thuộc tính bàn phím sẽ được
 * ghi đè bởi applyContentFieldStyle: cho ô nội dung).
 */
- (UITextField *)makeTextField:(NSString *)placeholder {
    UITextField *tf = [[UITextField alloc] init];
    tf.placeholder = placeholder;
    tf.font = [UIFont systemFontOfSize:14];
    tf.borderStyle = UITextBorderStyleRoundedRect;
    // Mặc định tắt các tính năng thông minh (dành cho ô hex / tag type / serial)
    tf.autocapitalizationType  = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType      = UITextAutocorrectionTypeNo;
    tf.spellCheckingType       = UITextSpellCheckingTypeNo;
    tf.smartDashesType         = UITextSmartDashesTypeNo;
    tf.smartQuotesType         = UITextSmartQuotesTypeNo;
    tf.smartInsertDeleteType   = UITextSmartInsertDeleteTypeNo;
    tf.clearButtonMode         = UITextFieldViewModeWhileEditing;
    tf.returnKeyType           = UIReturnKeyDone;
    return tf;
}

- (UIView *)createPresetButtons {
    UIButton *b1 = [UIButton buttonWithType:UIButtonTypeSystem];
    [b1 setTitle:@"Mifare Ultralight" forState:UIControlStateNormal];
    b1.titleLabel.font = [UIFont systemFontOfSize:11];
    [b1 addTarget:self action:@selector(presetUltralight) forControlEvents:UIControlEventTouchUpInside];

    UIButton *b2 = [UIButton buttonWithType:UIButtonTypeSystem];
    [b2 setTitle:@"Mifare Classic 1K" forState:UIControlStateNormal];
    b2.titleLabel.font = [UIFont systemFontOfSize:11];
    [b2 addTarget:self action:@selector(presetClassic) forControlEvents:UIControlEventTouchUpInside];

    UIButton *b3 = [UIButton buttonWithType:UIButtonTypeSystem];
    [b3 setTitle:@"ISO-DEP (Type A)" forState:UIControlStateNormal];
    b3.titleLabel.font = [UIFont systemFontOfSize:11];
    [b3 addTarget:self action:@selector(presetIsoDep) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *h = [[UIStackView alloc] initWithArrangedSubviews:@[b1, b2, b3]];
    h.axis = UILayoutConstraintAxisHorizontal;
    h.distribution = UIStackViewDistributionFillEqually;
    h.spacing = 6;
    return h;
}

#pragma mark - Preset Actions

- (void)presetUltralight {
    self.tagTypeField.text  = @"ISO 14443-3A - Mifare Ultralight";
    self.technologyField.text = @"Type A";
}

- (void)presetClassic {
    self.tagTypeField.text  = @"Mifare Classic 1K";
    self.technologyField.text = @"Type A";
}

- (void)presetIsoDep {
    self.tagTypeField.text    = @"ISO 14443-4 (Type A)";
    self.technologyField.text = @"ISO-DEP";
    if (self.currentDataType != 2) {
        self.writableSwitch.on = NO;
        [self writableChanged:self.writableSwitch];
    }
}

- (void)randomSerialTapped {
    uint8_t b[7]; arc4random_buf(b, 7); b[0] = 0x04;
    self.serialField.text = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X:%02X",
                             b[0], b[1], b[2], b[3], b[4], b[5], b[6]];
}

- (void)writableChanged:(UISwitch *)sw {
    if (self.currentDataType == 2) {
        sw.on = NO;
        self.writableHintLabel.text = @"Historical Bytes không hỗ trợ ghi — luôn ở chế độ ReadOnly";
    } else {
        self.writableHintLabel.text = sw.on
            ? @"Thẻ đang ở chế độ ReadWrite (Có thể đọc và ghi đè)"
            : @"Thẻ đang ở chế độ ReadOnly (Chỉ đọc, không cho phép ghi)";
    }
}

- (void)resetDefaultTapped {
    NFCTagConfig *def = [NFCTagConfig defaultConfig];
    self.tagTypeField.text    = @"";
    self.technologyField.text = @"";
    self.serialField.text     = @"";
    self.contentField.text    = @"";
    self.config = def;
    [self applyWritableState:self.currentDataType];
}

#pragma mark - Save / Close

- (void)saveTapped {
    [self.view endEditing:YES];

    NSString *tt      = [self.tagTypeField.text    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *tech    = [self.technologyField.text  stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *ser     = [self.serialField.text      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *content = [self.contentField.text     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    self.config.tagType            = (tt.length   > 0) ? tt   : @"Unknown";
    self.config.technology         = (tech.length > 0) ? tech : @"Unknown";
    self.config.serialNumber       = (ser.length  > 0) ? ser  : @"Unknown";
    // Historical Bytes: lưu giá trị hex vào config, Text/Link để trống trường này
    self.config.historicalBytesHex = (self.currentDataType == 2) ? content : @"";
    self.config.isWritable         = (self.currentDataType == 2) ? NO : self.writableSwitch.on;

    if (self.onSave) {
        self.onSave(self.config, content, self.currentDataType);
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)closeTapped {
    [self.view endEditing:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
