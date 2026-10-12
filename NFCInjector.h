#import <CoreNFC/CoreNFC.h>
#import <Foundation/Foundation.h>

typedef void(^NFCSessionDetectedBlock)(void);
typedef void(^NFCLogCallbackBlock)(NSString *logText);

@interface NFCInjector : NSObject

+ (instancetype)sharedInstance;

// Delegate, Session và Thẻ đang kết nối
@property(nonatomic, strong) id activeDelegate;
@property(nonatomic, strong) NFCReaderSession *activeSession;
@property(nonatomic, strong) id connectedTag;

// Trạng thái armed (chờ app bật quét NFC để tự động inject)
@property(nonatomic, assign) BOOL isArmed;
@property(nonatomic, strong) NFCNDEFMessage *armedMessage;
@property(nonatomic, copy) NFCSessionDetectedBlock onSessionDetected;

// Log buffer & callback
@property(nonatomic, copy) NFCLogCallbackBlock onLog;
@property(nonatomic, readonly, strong) NSMutableArray<NSString *> *logBuffer;

- (void)log:(NSString *)format, ...;
- (NSString *)allLogsString;
- (void)clearLogs;

- (void)armWithMessage:(NFCNDEFMessage *)message onSessionDetected:(NFCSessionDetectedBlock)block;
- (void)disarm;

- (BOOL)injectMessage:(NFCNDEFMessage *)message error:(NSError **)error;
- (BOOL)injectMessage:(NFCNDEFMessage *)message delay:(NSTimeInterval)delaySeconds error:(NSError **)error;
- (void)notifySessionStarted:(NFCReaderSession *)session delegate:(id)delegate;

@end
