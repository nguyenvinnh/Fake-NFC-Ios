#import "FakeNDEFTag.h"
#import "NFCInjector.h"

@implementation FakeNDEFTag

- (instancetype)initWithMessage:(NFCNDEFMessage *)message {
    // UID mặc định 7-byte Mifare
    unsigned char defaultUID[] = {0x04, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC};
    NSData *uid = [NSData dataWithBytes:defaultUID length:sizeof(defaultUID)];
    return [self initWithMessage:message uid:uid];
}

- (instancetype)initWithMessage:(NFCNDEFMessage *)message uid:(NSData *)uid {
    self = [super init];
    if (self) {
        _ndefMessage = message;
        _tagUID = uid ?: [NSData data];
        _isFakeTag = YES;
    }
    return self;
}

// MARK: - NFCNDEFTag Protocol
- (BOOL)isAvailable {
    return YES;
}

- (BOOL)available {
    return YES;
}

- (void)queryNDEFStatusWithCompletionHandler:(void(^)(NFCNDEFStatus status, NSUInteger capacity, NSError * _Nullable error))completionHandler {
    [[NFCInjector sharedInstance] log:@"[TAG] queryNDEFStatus: Trả về trạng thái ReadWrite 2048 bytes"];
    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(NFCNDEFStatusReadWrite, 2048, nil);
        });
    }
}

- (void)readNDEFWithCompletionHandler:(void(^)(NFCNDEFMessage * _Nullable message, NSError * _Nullable error))completionHandler {
    [[NFCInjector sharedInstance] log:@"[TAG] readNDEF: App đọc payload -> ĐÃ TRẢ VỀ PAYLOAD GIẢ THÀNH CÔNG!"];
    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(self.ndefMessage, nil);
        });
    }
}

- (void)writeNDEF:(NFCNDEFMessage *)ndefMessage completionHandler:(void(^)(NSError * _Nullable error))completionHandler {
    [[NFCInjector sharedInstance] log:@"[TAG] writeNDEF: App ghi NDEF mới"];
    self.ndefMessage = ndefMessage;
    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil);
        });
    }
}

- (void)writeLockWithCompletionHandler:(void(^)(NSError * _Nullable error))completionHandler {
    [[NFCInjector sharedInstance] log:@"[TAG] writeLock"];
    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil);
        });
    }
}

// MARK: - NFCTag Protocol
- (NFCTagType)type {
    return NFCTagTypeMiFare;
}

- (id<NFCISO7816Tag>)asNFCISO7816Tag {
    return nil;
}

- (id<NFCISO15693Tag>)asNFCISO15693Tag {
    return nil;
}

- (id<NFCMiFareTag>)asNFCMiFareTag {
    return self;
}

- (id<NFCFeliCaTag>)asNFCFeliCaTag {
    return nil;
}

// MARK: - NFCMiFareTag Protocol
- (NSData *)identifier {
    return self.tagUID;
}

- (NSData *)historicalBytes {
    return [NSData data];
}

- (NFCMiFareFamily)mifareFamily {
    return NFCMiFareUltralight;
}

- (void)sendMiFareCommand:(NSData *)command completionHandler:(void(^)(NSData *response, NSError *error))completionHandler {
    [[NFCInjector sharedInstance] log:@"[TAG] sendMiFareCommand"];
    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler([NSData data], nil);
        });
    }
}

- (void)sendMiFareISO7816Command:(NFCISO7816APDU *)apdu completionHandler:(void(^)(NSData *response, uint8_t sw1, uint8_t sw2, NSError *error))completionHandler {
    [[NFCInjector sharedInstance] log:@"[TAG] sendMiFareISO7816Command"];
    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler([NSData data], 0x90, 0x00, nil);
        });
    }
}

// MARK: - NSCopying & NSSecureCoding
+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    FakeNDEFTag *copy = [[FakeNDEFTag alloc] initWithMessage:self.ndefMessage uid:self.tagUID];
    copy.session = self.session;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.ndefMessage forKey:@"ndefMessage"];
    [coder encodeObject:self.tagUID forKey:@"tagUID"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NFCNDEFMessage *msg = [coder decodeObjectOfClass:[NFCNDEFMessage class] forKey:@"ndefMessage"];
    NSData *uid = [coder decodeObjectOfClass:[NSData class] forKey:@"tagUID"];
    return [self initWithMessage:msg uid:uid];
}

@end
