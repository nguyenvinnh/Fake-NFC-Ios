#import "NFCInjector.h"
#import "FakeNDEFTag.h"
#import <notify.h>
#import <dlfcn.h>
#import <objc/runtime.h>

@interface NFCInjector ()
@property(nonatomic, assign) int notifyToken;
@property(nonatomic, strong) NSMutableArray<NSString *> *internalLogBuffer;
@end

@implementation NFCInjector

+ (instancetype)sharedInstance {
  static NFCInjector *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[NFCInjector alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _notifyToken = NOTIFY_TOKEN_INVALID;
    _internalLogBuffer = [NSMutableArray array];
    [self log:@"[INIT] Khởi động FakeNFC Injector..."];
    [self loadNearFieldPrivateFramework];
    [self setupSystemNFCNotificationListener];
  }
  return self;
}

- (NSMutableArray<NSString *> *)logBuffer {
  return self.internalLogBuffer;
}

- (void)log:(NSString *)format, ... {
  va_list args;
  va_start(args, format);
  NSString *formatted = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);

  NSDateFormatter *df = [[NSDateFormatter alloc] init];
  [df setDateFormat:@"HH:mm:ss.SSS"];
  NSString *timeStr = [df stringFromDate:[NSDate date]];
  NSString *fullLog = [NSString stringWithFormat:@"[%@] %@", timeStr, formatted];

  NSLog(@"%@", fullLog);

  @synchronized(self.internalLogBuffer) {
    [self.internalLogBuffer addObject:fullLog];
    if (self.internalLogBuffer.count > 300) {
      [self.internalLogBuffer removeObjectAtIndex:0];
    }
  }

  if (self.onLog) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (self.onLog) {
        self.onLog(fullLog);
      }
    });
  }
}

- (NSString *)allLogsString {
  @synchronized(self.internalLogBuffer) {
    if (self.internalLogBuffer.count == 0) {
      return @"--- Chưa có nhật ký nào ---\n";
    }
    return [[self.internalLogBuffer componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
  }
}

- (void)clearLogs {
  @synchronized(self.internalLogBuffer) {
    [self.internalLogBuffer removeAllObjects];
  }
}

- (void)loadNearFieldPrivateFramework {
  void *handle = dlopen("/System/Library/PrivateFrameworks/NearField.framework/NearField", RTLD_NOW);
  if (handle) {
    [self log:@"[SYSTEM] Đã tải NearField.framework thành công!"];
  }
}

- (void)setupSystemNFCNotificationListener {
  const char *notifications[] = {
    "com.apple.nfcd.session.started",
    "com.apple.nfcd.field.detected",
    "com.apple.corenfc.reader.started",
    "FakeNFCReaderSessionDidStartNotification"
  };

  for (int i = 0; i < 4; i++) {
    int token;
    const char *name = notifications[i];
    notify_register_dispatch(name, &token, dispatch_get_main_queue(), ^(int t) {
      [self log:@"[EVENT] Nhận tín hiệu hệ thống: %s", name];
      [self handleSystemNFCSessionStarted];
    });
  }
}

- (void)armWithMessage:(NFCNDEFMessage *)message onSessionDetected:(NFCSessionDetectedBlock)block {
  self.isArmed = YES;
  self.armedMessage = message;
  self.onSessionDetected = block;
  [self log:@"[ARMED] ĐÃ BẬT CHẾ ĐỘ CHỜ TỰ ĐỘNG! Sẵn sàng bắt cửa sổ quét NFC..."];
}

- (void)disarm {
  self.isArmed = NO;
  self.armedMessage = nil;
  self.onSessionDetected = nil;
  [self log:@"[ARMED] Đã huỷ chế độ chờ tự động."];
}

- (void)notifySessionStarted:(NFCReaderSession *)session delegate:(id)delegate {
  if (session) self.activeSession = session;
  if (delegate) self.activeDelegate = delegate;
  [self log:@"[SESSION] Đã lưu phiên quét: <%@: %p> | delegate: <%@: %p>", [session class], session, [delegate class], delegate];
  [self handleSystemNFCSessionStarted];
}

- (void)handleSystemNFCSessionStarted {
  if (!self.isArmed || !self.armedMessage) {
    return;
  }

  [self log:@"[TRIGGER] >>> BẮT ĐƯỢC CỬA SỔ QUÉT NFC! BẮT ĐẦU ĐẨY DỮ LIỆU GIẢ <<<"];
  
  if (self.onSessionDetected) {
    self.onSessionDetected();
  }

  NFCNDEFMessage *msgToSend = self.armedMessage;
  [self disarm];

  [self injectMessage:msgToSend delay:0.3 error:nil];
}

- (BOOL)injectMessage:(NFCNDEFMessage *)message error:(NSError **)error {
  return [self injectMessage:message delay:0.3 error:error];
}

- (BOOL)injectMessage:(NFCNDEFMessage *)message delay:(NSTimeInterval)delaySeconds error:(NSError **)error {
  if (!message) {
    [self log:@"[ERROR] Bản ghi NDEF rỗng, không thể gửi!"];
    if (error) {
      *error = [NSError errorWithDomain:@"com.nguyenvinh.fakenfc"
                                   code:100
                               userInfo:@{NSLocalizedDescriptionKey : @"NDEF Message is nil."}];
    }
    return NO;
  }

  [self log:@"[INJECT] Bắt đầu quá trình tiêm NFC (chờ %.1fs)...", delaySeconds];

  // 1. Post notification
  notify_post("com.apple.nfcd.field.detected");
  notify_post("FakeNFCDidInjectMessageNotification");

  // 2. Delegate callback dispatch sau delay
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    id delegate = self.activeDelegate;
    NFCReaderSession *session = self.activeSession;

    // Nếu delegate chưa có từ hook init, lấy từ property delegate của session
    if (!delegate && session) {
      @try {
        delegate = [session valueForKey:@"delegate"];
      } @catch (NSException *e) {}
    }

    if (!delegate) {
      [self log:@"[INJECT] [CẢNH BÁO] Chưa bắt được delegate của ứng dụng mục tiêu. Hãy mở ứng dụng và bấm Scan/Read trước!"];
      return;
    }

    [self log:@"[INJECT] Tìm thấy delegate: <%@: %p>", [delegate class], delegate];

    // Tạo Mock Tag
    FakeNDEFTag *fakeTag = [[FakeNDEFTag alloc] initWithMessage:message];
    BOOL delivered = NO;

    // Hỗ trợ trường hợp 1: NFCNDEFReaderSessionDelegate didDetectTags: (iOS 13+ NDEF Reader)
    if ([delegate respondsToSelector:@selector(readerSession:didDetectTags:)]) {
      [self log:@"[INJECT] -> Gọi [delegate readerSession:didDetectTags:] với FakeNDEFTag!"];
      @try {
        [delegate readerSession:(NFCNDEFReaderSession *)session didDetectTags:@[ (id)fakeTag ]];
        delivered = YES;
      } @catch (NSException *e) {
        [self log:@"[INJECT] Lỗi gọi didDetectTags: %@", e];
      }
    }

    // Hỗ trợ trường hợp 2: NFCNDEFReaderSessionDelegate didDetectNDEFs: (Cổ điển)
    if (!delivered && [delegate respondsToSelector:@selector(readerSession:didDetectNDEFs:)]) {
      [self log:@"[INJECT] -> Gọi [delegate readerSession:didDetectNDEFs:] với message!"];
      @try {
        [delegate readerSession:(NFCNDEFReaderSession *)session didDetectNDEFs:@[ message ]];
        delivered = YES;
      } @catch (NSException *e) {
        [self log:@"[INJECT] Lỗi gọi didDetectNDEFs: %@", e];
      }
    }

    // Hỗ trợ trường hợp 3: NFCTagReaderSessionDelegate tagReaderSession:didDetectTags: (NFCTools & Tag Readers)
    SEL tagDetectSel = @selector(tagReaderSession:didDetectTags:);
    if (!delivered && [delegate respondsToSelector:tagDetectSel]) {
      [self log:@"[INJECT] -> Gọi [delegate tagReaderSession:didDetectTags:] với FakeNDEFTag!"];
      @try {
        void (*imp)(id, SEL, id, id) = (void (*)(id, SEL, id, id))[delegate methodForSelector:tagDetectSel];
        imp(delegate, tagDetectSel, session, @[ fakeTag ]);
        delivered = YES;
      } @catch (NSException *e) {
        [self log:@"[INJECT] Lỗi gọi tagReaderSession:didDetectTags: %@", e];
      }
    }

    if (delivered) {
      [self log:@"[INJECT] [THÀNH CÔNG] ĐÃ GỬI DỮ LIỆU FAKE THÀNH CÔNG VÀO ỨNG DỤNG MỤC TIÊU!"];
    } else {
      [self log:@"[INJECT] [LỖI] Delegate không hỗ trợ các phương thức nhận thẻ/NDEF đã biết."];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"FakeNFCDidInjectMessageNotification"
                                                        object:message];
  });

  return YES;
}

@end
