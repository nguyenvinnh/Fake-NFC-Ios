#import "NFCTagConfig.h"

@implementation NFCTagConfig

+ (instancetype)defaultConfig {
    NFCTagConfig *cfg = [[NFCTagConfig alloc] init];
    cfg.tagType = @"Mifare Ultralight";
    cfg.technology = @"Type A";
    cfg.serialNumber = @"04:12:34:56:78:9A:BC";
    cfg.historicalBytesHex = @"53:54:4D:73";
    cfg.isWritable = YES;
    return cfg;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _tagType = @"Mifare Ultralight";
        _technology = @"Type A";
        _serialNumber = @"04:12:34:56:78:9A:BC";
        _historicalBytesHex = @"";
        _isWritable = YES;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    NFCTagConfig *copy = [[NFCTagConfig allocWithZone:zone] init];
    copy.tagType = self.tagType;
    copy.technology = self.technology;
    copy.serialNumber = self.serialNumber;
    copy.historicalBytesHex = self.historicalBytesHex;
    copy.isWritable = self.isWritable;
    return copy;
}

- (NSDictionary *)toDictionary {
    return @{
        @"tagType": self.tagType ?: @"Unknown",
        @"technology": self.technology ?: @"Unknown",
        @"serialNumber": self.serialNumber ?: @"Unknown",
        @"historicalBytesHex": self.historicalBytesHex ?: @"",
        @"isWritable": @(self.isWritable)
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    NFCTagConfig *cfg = [[NFCTagConfig alloc] init];
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) {
        return [self defaultConfig];
    }
    cfg.tagType = dict[@"tagType"] ?: @"Mifare Ultralight";
    cfg.technology = dict[@"technology"] ?: @"Type A";
    cfg.serialNumber = dict[@"serialNumber"] ?: @"04:12:34:56:78:9A:BC";
    cfg.historicalBytesHex = dict[@"historicalBytesHex"] ?: @"";
    cfg.isWritable = dict[@"isWritable"] ? [dict[@"isWritable"] boolValue] : YES;
    return cfg;
}

static NSData *dataFromHex(NSString *hexStr) {
    if (!hexStr || hexStr.length == 0 || [hexStr isEqualToString:@"Unknown"]) {
        return [NSData data];
    }
    NSString *clean = [[hexStr stringByReplacingOccurrencesOfString:@":" withString:@""]
                              stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *data = [NSMutableData data];
    int idx = 0;
    while (idx + 2 <= clean.length) {
        NSRange range = NSMakeRange(idx, 2);
        NSString *byteStr = [clean substringWithRange:range];
        NSScanner *scanner = [NSScanner scannerWithString:byteStr];
        unsigned int byteVal = 0;
        if ([scanner scanHexInt:&byteVal]) {
            uint8_t b = (uint8_t)byteVal;
            [data appendBytes:&b length:1];
        }
        idx += 2;
    }
    return data;
}

- (NSData *)serialData {
    NSData *d = dataFromHex(self.serialNumber);
    if (d.length == 0) {
        // Mặc định UID 7-byte
        unsigned char defaultUID[] = {0x04, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC};
        return [NSData dataWithBytes:defaultUID length:sizeof(defaultUID)];
    }
    return d;
}

- (NSData *)historicalData {
    return dataFromHex(self.historicalBytesHex);
}

@end
