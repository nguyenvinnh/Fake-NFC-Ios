#import <Foundation/Foundation.h>

@interface NFCTemplateModel : NSObject

@property(nonatomic, copy) NSString *templateId;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *value;
@property(nonatomic, assign) NSInteger type; // 0: Text, 1: Link

- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value type:(NSInteger)type;
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
