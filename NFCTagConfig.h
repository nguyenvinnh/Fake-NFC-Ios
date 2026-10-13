#import <Foundation/Foundation.h>

@interface NFCTagConfig : NSObject <NSCopying>

// 1. Loại thẻ: "Mifare Ultralight", "Mifare Classic", "Mifare Plus", "Mifare DESFire", "ISO 14443-4 (Type A)", "ISO 15693 (Type V)", "FeliCa"
@property(nonatomic, copy) NSString *tagType;

// 2. Công nghệ: "Type A", "Type B", "Type F", "Type V", "ISO-DEP"
@property(nonatomic, copy) NSString *technology;

// 3. Số Serial thẻ (UID Hex string, vd: "04:12:34:56:78:9A:BC")
@property(nonatomic, copy) NSString *serialNumber;

// 4. Historical Bytes (Hex string, vd: "53:54:4D:73")
@property(nonatomic, copy) NSString *historicalBytesHex;

// 5. Khả năng ghi
@property(nonatomic, assign) BOOL isWritable;

+ (instancetype)defaultConfig;
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
- (NSData *)serialData;
- (NSData *)historicalData;

@end
