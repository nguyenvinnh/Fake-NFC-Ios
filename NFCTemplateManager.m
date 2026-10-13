#import "NFCTemplateManager.h"

static NSString *const kNFCTemplatesKey = @"FakeNFC_SavedTemplates";

@implementation NFCTemplateModel

- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value type:(NSInteger)type {
    self = [super init];
    if (self) {
        _templateId = [[NSUUID UUID] UUIDString];
        _title = [title copy] ?: @"";
        _value = [value copy] ?: @"";
        _type = type;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"id": self.templateId ?: @"",
        @"title": self.title ?: @"",
        @"value": self.value ?: @"",
        @"type": @(self.type)
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    NFCTemplateModel *model = [[NFCTemplateModel alloc] init];
    model.templateId = dict[@"id"] ?: [[NSUUID UUID] UUIDString];
    model.title = dict[@"title"] ?: @"";
    model.value = dict[@"value"] ?: @"";
    model.type = [dict[@"type"] integerValue];
    return model;
}

@end

@interface NFCTemplateManager ()
@property(nonatomic, strong) NSMutableArray<NFCTemplateModel *> *templatesList;
@end

@implementation NFCTemplateManager

+ (instancetype)sharedManager {
    static NFCTemplateManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NFCTemplateManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _templatesList = [NSMutableArray array];
        [self loadTemplates];
    }
    return self;
}

- (void)loadTemplates {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:kNFCTemplatesKey];
    [self.templatesList removeAllObjects];
    if ([saved isKindOfClass:[NSArray class]] && saved.count > 0) {
        for (NSDictionary *dict in saved) {
            if ([dict isKindOfClass:[NSDictionary class]]) {
                [self.templatesList addObject:[NFCTemplateModel fromDictionary:dict]];
            }
        }
    } else {
        // Mẫu tiếng Việt có dấu mặc định
        NFCTemplateModel *m1 = [[NFCTemplateModel alloc] initWithTitle:@"Genshin Impact Wiki" value:@"https://genshin-impact.fandom.com/vi/wiki/Nhân_Vật" type:1];
        NFCTemplateModel *m2 = [[NFCTemplateModel alloc] initWithTitle:@"Thẻ sinh viên" value:@"MSSV: 20261012 - Họ tên: Nguyễn Văn A" type:0];
        NFCTemplateModel *m3 = [[NFCTemplateModel alloc] initWithTitle:@"Google Tìm Kiếm" value:@"https://google.com" type:1];
        [self.templatesList addObject:m1];
        [self.templatesList addObject:m2];
        [self.templatesList addObject:m3];
        [self saveTemplates];
    }
}

- (void)saveTemplates {
    NSMutableArray *arr = [NSMutableArray array];
    for (NFCTemplateModel *m in self.templatesList) {
        [arr addObject:[m toDictionary]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:kNFCTemplatesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray<NFCTemplateModel *> *)allTemplates {
    return [self.templatesList copy];
}

- (void)addTemplate:(NFCTemplateModel *)model {
    if (!model) return;
    [self.templatesList insertObject:model atIndex:0];
    [self saveTemplates];
}

- (void)updateTemplate:(NFCTemplateModel *)model {
    if (!model) return;
    for (NSUInteger i = 0; i < self.templatesList.count; i++) {
        if ([self.templatesList[i].templateId isEqualToString:model.templateId]) {
            self.templatesList[i] = model;
            break;
        }
    }
    [self saveTemplates];
}

- (void)deleteTemplateWithId:(NSString *)templateId {
    if (!templateId) return;
    NSIndexSet *toRemove = [self.templatesList indexesOfObjectsPassingTest:^BOOL(NFCTemplateModel *obj, NSUInteger idx, BOOL *stop) {
        return [obj.templateId isEqualToString:templateId];
    }];
    [self.templatesList removeObjectsAtIndexes:toRemove];
    [self saveTemplates];
}

@end
