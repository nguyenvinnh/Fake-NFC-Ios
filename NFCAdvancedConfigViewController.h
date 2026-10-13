#import <UIKit/UIKit.h>
#import "NFCTagConfig.h"

/**
 * Block trả về khi lưu:
 * - updatedConfig : cấu hình phần cứng thẻ đã chỉnh
 * - content       : nội dung dữ liệu (văn bản, URL, hoặc hex historical bytes)
 * - dataType      : loại dữ liệu (0=Văn bản, 1=Đường dẫn, 2=Historical Bytes)
 */
typedef void(^NFCTagConfigSaveBlock)(NFCTagConfig *updatedConfig, NSString *content, NSInteger dataType);

@interface NFCAdvancedConfigViewController : UIViewController

@property(nonatomic, strong) NFCTagConfig *config;
@property(nonatomic, copy)   NFCTagConfigSaveBlock onSave;

/**
 * Khởi tạo với cấu hình thẻ + nội dung + loại dữ liệu hiện tại từ màn hình chính.
 * @param config      Cấu hình phần cứng thẻ hiện tại
 * @param content     Nội dung đang nhập ở màn hình chính (văn bản / URL / hex)
 * @param dataType    Loại dữ liệu đang chọn (0=Văn bản, 1=Đường dẫn, 2=Historical Bytes)
 * @param onSave      Callback trả về config + content + dataType khi lưu
 */
- (instancetype)initWithConfig:(NFCTagConfig *)config
                       content:(NSString *)content
                      dataType:(NSInteger)dataType
                        onSave:(NFCTagConfigSaveBlock)onSave;

@end
