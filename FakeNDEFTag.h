#import <Foundation/Foundation.h>
#import <CoreNFC/CoreNFC.h>

@interface FakeNDEFTag : NSObject <NFCNDEFTag, NFCTag, NFCMiFareTag>

@property(nonatomic, strong) NFCNDEFMessage *ndefMessage;
@property(nonatomic, copy) NSData *tagUID;
@property(nonatomic, assign) BOOL isFakeTag;
@property(nonatomic, weak) id<NFCReaderSession> session;

- (instancetype)initWithMessage:(NFCNDEFMessage *)message;
- (instancetype)initWithMessage:(NFCNDEFMessage *)message uid:(NSData *)uid;

@end
