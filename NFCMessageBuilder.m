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
    // Chuẩn NDEF Text Record định dạng UTF-8 (chuẩn NFC Forum RTD RFC 2141)
    // Bit 7 của Status byte = 0 (UTF-8), Bit 0-5 = độ dài mã ngôn ngữ (2 bytes: "vi")
    NSData *langData = [@"vi" dataUsingEncoding:NSUTF8StringEncoding];
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
    // Xử lý link có ký tự có dấu / unicode (như tiếng Việt, ký tự đặc biệt)
    NSURL *url = [NSURL URLWithString:trimmed];
    if (!url || !url.scheme) {
      // Encode URL nếu có ký tự có dấu trong path / query
      NSString *encoded = [trimmed stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
      url = [NSURL URLWithString:encoded];
    }

    if (url && url.scheme) {
      payload = [NFCNDEFPayload wellKnownTypeURIPayloadWithURL:url];
    }
    if (!payload) {
      payload = [NFCNDEFPayload wellKnownTypeURIPayloadWithString:trimmed];
    }

    // Nếu các phương thức mặc định vẫn chưa tạo được payload (do ký tự tiếng Việt đặc thù), tự build NDEF URI thô theo NFC Forum RTD URI
    if (!payload) {
      // Prefix 0x00: Không dùng prefix viết tắt
      // Prefix 0x01: http://www.
      // Prefix 0x02: https://www.
      // Prefix 0x03: http://
      // Prefix 0x04: https://
      uint8_t prefixCode = 0x00;
      NSString *subUri = trimmed;
      if ([trimmed hasPrefix:@"https://www."]) {
        prefixCode = 0x02;
        subUri = [trimmed substringFromIndex:12];
      } else if ([trimmed hasPrefix:@"http://www."]) {
        prefixCode = 0x01;
        subUri = [trimmed substringFromIndex:11];
      } else if ([trimmed hasPrefix:@"https://"]) {
        prefixCode = 0x04;
        subUri = [trimmed substringFromIndex:8];
      } else if ([trimmed hasPrefix:@"http://"]) {
        prefixCode = 0x03;
        subUri = [trimmed substringFromIndex:7];
      }

      NSData *uriData = [subUri dataUsingEncoding:NSUTF8StringEncoding];
      if (uriData) {
        NSMutableData *uriPayload = [NSMutableData dataWithBytes:&prefixCode length:1];
        [uriPayload appendData:uriData];
        NSData *typeData = [NSData dataWithBytes:"U" length:1];
        payload = [[NFCNDEFPayload alloc] initWithFormat:NFCTypeNameFormatNFCWellKnown
                                                    type:typeData
                                              identifier:[NSData data]
                                                 payload:uriPayload];
      }
    }

    if (!payload) {
      if (error)
        *error = [NSError errorWithDomain:AFNFCErrorDomain
                                     code:2
                                 userInfo:@{
                                   NSLocalizedDescriptionKey : @"Đường dẫn không hợp lệ. Vui lòng kiểm tra lại."
                                 }];
      return nil;
    }
  }

  if (!payload) {
    if (error)
      *error = [NSError
          errorWithDomain:AFNFCErrorDomain
                     code:3
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Không tạo được bản ghi NDEF."
                 }];
    return nil;
  }

  return [[NFCNDEFMessage alloc] initWithNDEFRecords:@[ payload ]];
}

@end