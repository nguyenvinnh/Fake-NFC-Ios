#import <Foundation/Foundation.h>
#import <CoreNFC/CoreNFC.h>
#import "NFCTagConfig.h"

@interface FakeNDEFTag : NSObject <NFCNDEFTag, NFCTag, NFCMiFareTag, NFCISO7816Tag>

@property(nonatomic, strong) NFCNDEFMessage *ndefMessage;
@property(nonatomic, copy) NSData *tagUID;
@property(nonatomic, copy) NSData *tagHistoricalBytes;
@property(nonatomic, assign) BOOL isFakeTag;
@property(nonatomic, assign) BOOL isWritable;
@property(nonatomic, strong) NFCTagConfig *config;
@property(nonatomic, weak) id<NFCReaderSession> session;

- (instancetype)initWithMessage:(NFCNDEFMessage *)message;
- (instancetype)initWithMessage:(NFCNDEFMessage *)message config:(NFCTagConfig *)config;

@end
