#import "NFCTemplateManager.h"

static NSString *const kNFCTemplatesKey = @"FakeNFC_SavedTemplates";

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - NFCTemplateModel
// ─────────────────────────────────────────────────────────────────────────────

@implementation NFCTemplateModel

- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value type:(NSInteger)type {
    return [self initWithTitle:title value:value type:type tagConfig:nil];
}

- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value type:(NSInteger)type tagConfig:(NFCTagConfig *)tagConfig {
    self = [super init];
    if (self) {
        _templateId = [[NSUUID UUID] UUIDString];
        _title      = [title copy] ?: @"";
        _value      = [value copy] ?: @"";
        _type       = type;
        _tagConfig  = tagConfig ? [tagConfig copy] : nil;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [@{
        @"id"    : self.templateId ?: @"",
        @"title" : self.title      ?: @"",
        @"value" : self.value      ?: @"",
        @"type"  : @(self.type),
    } mutableCopy];

    if (self.tagConfig) {
        d[@"tagConfig"] = @{
            @"tagType"           : self.tagConfig.tagType           ?: @"Unknown",
            @"technology"        : self.tagConfig.technology        ?: @"Unknown",
            @"serialNumber"      : self.tagConfig.serialNumber      ?: @"Unknown",
            @"historicalBytesHex": self.tagConfig.historicalBytesHex ?: @"",
            @"isWritable"        : @(self.tagConfig.isWritable),
        };
    }
    return [d copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    NFCTemplateModel *m = [[NFCTemplateModel alloc] init];
    m.templateId = dict[@"id"]    ?: [[NSUUID UUID] UUIDString];
    m.title      = dict[@"title"] ?: @"";
    m.value      = dict[@"value"] ?: @"";
    m.type       = [dict[@"type"] integerValue];

    NSDictionary *cfgDict = dict[@"tagConfig"];
    if ([cfgDict isKindOfClass:[NSDictionary class]]) {
        NFCTagConfig *cfg        = [[NFCTagConfig alloc] init];
        cfg.tagType              = cfgDict[@"tagType"]            ?: @"Unknown";
        cfg.technology           = cfgDict[@"technology"]         ?: @"Unknown";
        cfg.serialNumber         = cfgDict[@"serialNumber"]       ?: @"Unknown";
        cfg.historicalBytesHex   = cfgDict[@"historicalBytesHex"] ?: @"";
        cfg.isWritable           = [cfgDict[@"isWritable"] boolValue];
        m.tagConfig = cfg;
    }
    return m;
}

@end

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - NFCTemplateManager
// ─────────────────────────────────────────────────────────────────────────────

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
            NFCTemplateModel *m = [NFCTemplateModel fromDictionary:dict];
            if (m) [self.templatesList addObject:m];
        }
    } else {
        // Mẫu mặc định có sẵn khi cài lần đầu
        NFCTemplateModel *m1 = [[NFCTemplateModel alloc]
            initWithTitle:@"Genshin Impact Wiki"
                    value:@"https://genshin-impact.fandom.com/vi/wiki/Nhân_Vật"
                     type:1
                tagConfig:[NFCTagConfig defaultConfig]];
        NFCTemplateModel *m2 = [[NFCTemplateModel alloc]
            initWithTitle:@"Thẻ sinh viên"
                    value:@"MSSV: 20261012 - Họ tên: Nguyễn Văn A"
                     type:0
                tagConfig:[NFCTagConfig defaultConfig]];
        NFCTemplateModel *m3 = [[NFCTemplateModel alloc]
            initWithTitle:@"Google"
                    value:@"https://google.com"
                     type:1
                tagConfig:[NFCTagConfig defaultConfig]];
        [self.templatesList addObjectsFromArray:@[m1, m2, m3]];
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
    NSIndexSet *idx = [self.templatesList indexesOfObjectsPassingTest:^BOOL(NFCTemplateModel *obj, NSUInteger i, BOOL *stop) {
        return [obj.templateId isEqualToString:templateId];
    }];
    [self.templatesList removeObjectsAtIndexes:idx];
    [self saveTemplates];
}

@end
