#import "NFCTemplatesViewController.h"

@interface NFCTemplatesViewController ()
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSMutableArray<NFCTemplateModel *> *templates;
@end

@implementation NFCTemplatesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Danh sach mau";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Them"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(addTapped)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];

    [self reloadData];
}

- (void)reloadData {
    self.templates = [[[NFCTemplateManager sharedManager] allTemplates] mutableCopy];
    [self.tableView reloadData];
}

- (void)addTapped {
    [self showEditAlertForModel:nil];
}

- (void)showEditAlertForModel:(NFCTemplateModel *)model {
    BOOL isEdit = (model != nil);
    NSString *alertTitle = isEdit ? @"Sua mau" : @"Them mau moi";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Ten mau (Vi du: The sinh vien)";
        if (isEdit) textField.text = model.title;
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Noi dung (Link hoac Text)";
        if (isEdit) textField.text = model.value;
    }];

    __block NSInteger selectedType = isEdit ? model.type : 1; // Mac dinh Link
    NSString *toggleTitle = (selectedType == 0) ? @"Dang chon: Text (Bam de doi sang Link)" : @"Dang chon: Link (Bam de doi sang Text)";
    UIAlertAction *toggleTypeAction = [UIAlertAction actionWithTitle:toggleTitle
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) {
        selectedType = (selectedType == 1) ? 0 : 1;
        // Hien lai alert voi loai da doi
        NSString *curTitle = alert.textFields[0].text;
        NSString *curVal = alert.textFields[1].text;
        NFCTemplateModel *temp = [[NFCTemplateModel alloc] initWithTitle:curTitle value:curVal type:selectedType];
        if (isEdit) temp.templateId = model.templateId;
        [self showEditAlertForModel:temp];
    }];

    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Luu"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        NSString *t = alert.textFields[0].text;
        NSString *v = alert.textFields[1].text;
        if (t.length == 0) t = @"Mau khong ten";

        if (isEdit) {
            model.title = t;
            model.value = v;
            model.type = selectedType;
            [[NFCTemplateManager sharedManager] updateTemplate:model];
        } else {
            NFCTemplateModel *newModel = [[NFCTemplateModel alloc] initWithTitle:t value:v type:selectedType];
            [[NFCTemplateManager sharedManager] addTemplate:newModel];
        }
        [self reloadData];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Huy"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:toggleTypeAction];
    [alert addAction:saveAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.templates.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"TemplateCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }

    NFCTemplateModel *model = self.templates[indexPath.row];
    NSString *typeStr = (model.type == 0) ? @"[Text]" : @"[Link]";
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", typeStr, model.title];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.detailTextLabel.text = model.value;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NFCTemplateModel *model = self.templates[indexPath.row];

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:model.title
                                                                         message:model.value
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *useAction = [UIAlertAction actionWithTitle:@"Su dung mau nay"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        if (self.onSelectTemplate) {
            self.onSelectTemplate(model);
        }
        [self.navigationController popViewControllerAnimated:YES];
    }];

    UIAlertAction *editAction = [UIAlertAction actionWithTitle:@"Sua mau"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        [self showEditAlertForModel:model];
    }];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Xoa mau"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
        [[NFCTemplateManager sharedManager] deleteTemplateWithId:model.templateId];
        [self reloadData];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Dong"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [actionSheet addAction:useAction];
    [actionSheet addAction:editAction];
    [actionSheet addAction:deleteAction];
    [actionSheet addAction:cancelAction];

    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NFCTemplateModel *model = self.templates[indexPath.row];
        [[NFCTemplateManager sharedManager] deleteTemplateWithId:model.templateId];
        [self.templates removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

@end
