#import <UIKit/UIKit.h>
#import "NFCTemplateManager.h"

typedef void(^NFCTemplateSelectBlock)(NFCTemplateModel *selectedModel);

@interface NFCTemplatesViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, copy) NFCTemplateSelectBlock onSelectTemplate;

@end
