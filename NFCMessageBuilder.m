#import "NFCMessageBuilder.h"

static NSString *const AFNFCErrorDomain = @"com.nguyenvinh.fakenfc";

@implementation NFCMessageBuilder

+ (NFCNDEFMessage *)messageForType:(AFNFCInputType)type
                             value:(NSString *)value
                             error:(NSError **)error {
  NSString *trimmed = [value
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
  if (trimmed.length == 0) {
    if (error)
      *error = [NSError
          errorWithDomain:AFNFCErrorDomain
                     code:1
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Dữ liệu không được để trống."
                 }];
    return nil;
  }

  NFCNDEFPayload *payload = nil;

  if (type == AFNFCInputTypeText) {
    // Tạo chuẩn NDEF Text Record định dạng UTF-8 (chuẩn NFC Forum RTD RFC 2141)
    // Bit 7 của Status byte = 0 (UTF-8, tránh bị dính BOM UTF-16 ÿþ), Bit 0-5 = độ dài mã ngôn ngữ
    NSData *langData = [@"en" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *textData = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t statusByte = (uint8_t)(langData.length & 0x3F);

    NSMutableData *fullPayload = [NSMutableData dataWithBytes:&statusByte length:1];
    [fullPayload appendData:langData];
    [fullPayload appendData:textData];

    NSData *typeData = [NSData dataWithBytes:"T" length:1];
    payload = [[NFCNDEFPayload alloc] initWithFormat:NFCTypeNameFormatNFCWellKnown
                                                type:typeData
                                          identifier:[NSData data]
                                             payload:fullPayload];
  } else {
    // Chuẩn NDEF URI Record (Format 0x01 Well Known, Type 'U')
    NSURL *url = [NSURL URLWithString:trimmed];
    if (!url || !url.scheme || !url.host) {
      if (error)
        *error =
            [NSError errorWithDomain:AFNFCErrorDomain
                                code:2
                            userInfo:@{
                              NSLocalizedDescriptionKey : @"Link không hợp lệ (cần có http:// hoặc https://)."
                            }];
      return nil;
    }
    payload = [NFCNDEFPayload wellKnownTypeURIPayloadWithURL:url];
    if (!payload) {
      payload = [NFCNDEFPayload wellKnownTypeURIPayloadWithString:trimmed];
    }
  }

  if (!payload) {
    if (error)
      *error = [NSError
          errorWithDomain:AFNFCErrorDomain
                     code:3
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Không tạo được NDEF payload."
                 }];
    return nil;
  }

  return [[NFCNDEFMessage alloc] initWithNDEFRecords:@[ payload ]];
}

@end