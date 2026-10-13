#import "FakeNDEFTag.h"
#import "NFCInjector.h"

@implementation FakeNDEFTag

- (instancetype)initWithMessage:(NFCNDEFMessage *)message {
    return [self initWithMessage:message config:[NFCTagConfig defaultConfig]];
}

- (instancetype)initWithMessage:(NFCNDEFMessage *)message config:(NFCTagConfig *)config {
    self = [super init];
    if (self) {
        _ndefMessage = message;
        _config = config ? [config copy] : [NFCTagConfig defaultConfig];
        _tagUID = [_config serialData];
        _tagHistoricalBytes = [_config historicalData];
        _isWritable = _config.isWritable;
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
    NFCNDEFStatus status = self.isWritable ? NFCNDEFStatusReadWrite : NFCNDEFStatusReadOnly;
    [[NFCInjector sharedInstance] log:@"[TAG] queryNDEFStatus: Trả về trạng thái %@ (2048 bytes)", self.isWritable ? @"ReadWrite" : @"ReadOnly"];
    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(status, 2048, nil);
        });
    }
}

- (void)readNDEFWithCompletionHandler:(void(^)(NFCNDEFMessage * _Nullable message, NSError * _Nullable error))completionHandler {
    [[NFCInjector sharedInstance] log:@"[TAG] readNDEF: App đọc payload -> ĐÃ TRẢ VỀ DỮ LIỆU FAKE!"];
    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(self.ndefMessage, nil);
        });
    }
}

- (void)writeNDEF:(NFCNDEFMessage *)ndefMessage completionHandler:(void(^)(NSError * _Nullable error))completionHandler {
    if (!self.isWritable) {
        [[NFCInjector sharedInstance] log:@"[TAG] writeNDEF: Thẻ đang ở chế độ chỉ đọc (ReadOnly/Historical Bytes), từ chối ghi."];
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *err = [NSError errorWithDomain:@"com.apple.corenfc" code:102 userInfo:@{NSLocalizedDescriptionKey: @"Tag is read-only."}];
                completionHandler(err);
            });
        }
        return;
    }
    [[NFCInjector sharedInstance] log:@"[TAG] writeNDEF: App ghi NDEF mới thành công"];
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
    NSString *t = [self.config.tagType lowercaseString];
    if ([t containsString:@"iso15693"] || [t containsString:@"type v"]) {
        return NFCTagTypeISO15693;
    } else if ([t containsString:@"felica"] || [t containsString:@"type f"]) {
        return NFCTagTypeFeliCa;
    } else if ([t containsString:@"7816"] || [t containsString:@"iso-dep"]) {
        return NFCTagTypeISO7816Compatible;
    }
    return NFCTagTypeMiFare;
}

- (id<NFCISO7816Tag>)asNFCISO7816Tag {
    return self;
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
    return self.tagHistoricalBytes ?: [NSData data];
}

- (NFCMiFareFamily)mifareFamily {
    NSString *t = [self.config.tagType lowercaseString];
    if ([t containsString:@"classic"]) {
        return NFCMiFarePlus; // hoặc tương thích
    } else if ([t containsString:@"desfire"]) {
        return NFCMiFareDESFire;
    }
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

// MARK: - NFCISO7816Tag Protocol
- (NSData *)applicationData {
    return [NSData data];
}

- (NSString *)initialSelectedAID {
    return @"A0000002471001";
}

- (BOOL)proprietaryApplicationDataCoding {
    return NO;
}

- (void)sendCommandAPDU:(NFCISO7816APDU *)apdu completionHandler:(void(^)(NSData *responseData, uint8_t sw1, uint8_t sw2, NSError *error))completionHandler {
    [[NFCInjector sharedInstance] log:@"[TAG] sendCommandAPDU"];
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
    FakeNDEFTag *copy = [[FakeNDEFTag alloc] initWithMessage:self.ndefMessage config:self.config];
    copy.session = self.session;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.ndefMessage forKey:@"ndefMessage"];
    [coder encodeObject:self.tagUID forKey:@"tagUID"];
    [coder encodeObject:self.tagHistoricalBytes forKey:@"tagHistoricalBytes"];
    [coder encodeBool:self.isWritable forKey:@"isWritable"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NFCNDEFMessage *msg = [coder decodeObjectOfClass:[NFCNDEFMessage class] forKey:@"ndefMessage"];
    FakeNDEFTag *tag = [[FakeNDEFTag alloc] initWithMessage:msg];
    tag.tagUID = [coder decodeObjectOfClass:[NSData class] forKey:@"tagUID"];
    tag.tagHistoricalBytes = [coder decodeObjectOfClass:[NSData class] forKey:@"tagHistoricalBytes"];
    tag.isWritable = [coder decodeBoolForKey:@"isWritable"];
    return tag;
}

@end
