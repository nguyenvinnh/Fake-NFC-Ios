#import <UIKit/UIKit.h>
#import <CoreNFC/CoreNFC.h>
#import "FakeNFCFloatManager.h"
#import "FakeNFCViewController.h"
#import "NFCInjector.h"
#import "FakeNDEFTag.h"

// MARK: - Kích hoạt floating button khi app khởi động
%hook UIApplication

- (BOOL)application:(id)app didFinishLaunchingWithOptions:(id)opts {
    BOOL result = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[FakeNFC] Injected into %@. Hiển thị nút tròn nổi...", [[NSBundle mainBundle] bundleIdentifier]);
        [[FakeNFCFloatManager sharedManager] showFloatButton];
    });
    return result;
}

%end

// MARK: - Hook Base Class NFCReaderSession
%hook NFCReaderSession

+ (BOOL)readingAvailable {
    return YES;
}

- (void)beginSession {
    NSLog(@"[FakeNFC] [NFCReaderSession beginSession] được gọi bởi app mục tiêu: %@", self);
    %orig;

    id delegate = nil;
    @try {
        delegate = [self valueForKey:@"delegate"];
    } @catch (NSException *e) {}

    NFCInjector *injector = [NFCInjector sharedInstance];
    injector.activeSession = self;
    if (delegate) {
        injector.activeDelegate = delegate;
    }

    [injector log:@"[SESSION] App mục tiêu gọi beginSession: <%@: %p> | delegate: <%@: %p>",
                  [self class], self, [delegate class], delegate];

    // Nếu đang ở chế độ armed: kích hoạt inject ngay
    if (injector.isArmed && injector.armedMessage) {
        [[FakeNFCFloatManager sharedManager] setState:FakeNFCFloatStateInjecting label:@"INJECT"];
        [injector notifySessionStarted:self delegate:injector.activeDelegate];
    }
}

- (void)invalidateSession {
    [[NFCInjector sharedInstance] log:@"[SESSION] invalidateSession (app đóng phiên quét)."];
    %orig;
}

- (void)invalidateSessionWithErrorMessage:(NSString *)errorMessage {
    [[NFCInjector sharedInstance] log:@"[SESSION] invalidateSessionWithErrorMessage: %@", errorMessage];
    %orig;
}

%end

// MARK: - Hook NFCTagReaderSession (Dành cho NFC Tools & Tag Readers)
%hook NFCTagReaderSession

+ (BOOL)readingAvailable {
    return YES;
}

- (instancetype)initWithPollingOption:(NSInteger)pollingOption
                             delegate:(id)delegate
                                queue:(dispatch_queue_t)queue {
    NSLog(@"[FakeNFC] NFCTagReaderSession init với delegate: %@", delegate);
    NFCTagReaderSession *session = %orig;

    [NFCInjector sharedInstance].activeDelegate = delegate;
    [NFCInjector sharedInstance].activeSession = session;
    [[NFCInjector sharedInstance] log:@"[SESSION] Tạo phiên NFCTagReader: delegate=<%@: %p>", [delegate class], delegate];

    return session;
}

- (void)connectToTag:(id<NFCTag>)tag completionHandler:(void (^)(NSError * _Nullable error))completionHandler {
    NSLog(@"[FakeNFC] [NFCTagReaderSession connectToTag:] gọi với thẻ: %@", tag);
    [[NFCInjector sharedInstance] log:@"[SESSION] -> App yêu cầu connectToTag: <%@: %p>", [tag class], tag];

    [NFCInjector sharedInstance].connectedTag = tag;

    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NFCInjector sharedInstance] log:@"[SESSION] -> Kết nối thẻ THÀNH CÔNG (error=nil)"];
            completionHandler(nil);
        });
    }
}

- (id<NFCTag>)connectedTag {
    if ([NFCInjector sharedInstance].connectedTag) {
        return [NFCInjector sharedInstance].connectedTag;
    }
    return %orig;
}

- (void)restartPolling {
    [[NFCInjector sharedInstance] log:@"[SESSION] App gọi restartPolling"];
    %orig;
    NFCInjector *injector = [NFCInjector sharedInstance];
    if (injector.armedMessage) {
        [injector injectMessage:injector.armedMessage delay:0.3 error:nil];
    }
}

%end

// MARK: - Hook NFCNDEFReaderSession
%hook NFCNDEFReaderSession

+ (BOOL)readingAvailable {
    return YES;
}

- (instancetype)initWithDelegate:(id<NFCNDEFReaderSessionDelegate>)delegate
                           queue:(dispatch_queue_t)queue
        invalidateAfterFirstRead:(BOOL)invalidate {
    NSLog(@"[FakeNFC] NFCNDEFReaderSession init với delegate: %@", delegate);
    NFCNDEFReaderSession *session = %orig;

    [NFCInjector sharedInstance].activeDelegate = delegate;
    [NFCInjector sharedInstance].activeSession = session;
    [[NFCInjector sharedInstance] log:@"[SESSION] Tạo phiên NFCNDEF: delegate=<%@: %p>", [delegate class], delegate];

    return session;
}

- (void)connectToTag:(id<NFCNDEFTag>)tag completionHandler:(void (^)(NSError * _Nullable error))completionHandler {
    NSLog(@"[FakeNFC] [NFCNDEFReaderSession connectToTag:] gọi với NDEF thẻ: %@", tag);
    [[NFCInjector sharedInstance] log:@"[SESSION] -> App yêu cầu connectToTag (NDEF): <%@: %p>", [tag class], tag];

    [NFCInjector sharedInstance].connectedTag = tag;

    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NFCInjector sharedInstance] log:@"[SESSION] -> Kết nối NDEF thẻ THÀNH CÔNG (error=nil)"];
            completionHandler(nil);
        });
    }
}

- (void)restartPolling {
    [[NFCInjector sharedInstance] log:@"[SESSION] App gọi restartPolling"];
    %orig;
}

%end

// MARK: - Lắc máy để hiện lại nút nếu lỡ ẩn
%hook UIWindow

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    if (motion == UIEventSubtypeMotionShake) {
        [[FakeNFCFloatManager sharedManager] showFloatButton];
    }
}

%end