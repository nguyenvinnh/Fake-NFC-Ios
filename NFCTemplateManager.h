#import <Foundation/Foundation.h>
#import "NFCTagConfig.h"

// Kiểu dữ liệu của mẫu NFC
// 0 = Văn bản (Text), 1 = Đường dẫn (Link), 2 = Historical Bytes

@interface NFCTemplateModel : NSObject

@property(nonatomic, copy)   NSString     *templateId;
@property(nonatomic, copy)   NSString     *title;
@property(nonatomic, copy)   NSString     *value;
@property(nonatomic, assign) NSInteger     type;       // 0=Text, 1=Link, 2=Historical Bytes
@property(nonatomic, strong) NFCTagConfig *tagConfig;  // Cấu hình phần cứng thẻ (nil = dùng mặc định)

- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value type:(NSInteger)type;
- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value type:(NSInteger)type tagConfig:(NFCTagConfig *)tagConfig;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

@interface NFCTemplateManager : NSObject

+ (instancetype)sharedManager;

- (NSArray<NFCTemplateModel *> *)allTemplates;
- (void)addTemplate:(NFCTemplateModel *)model;
- (void)updateTemplate:(NFCTemplateModel *)model;
- (void)deleteTemplateWithId:(NSString *)templateId;

@end
