#import <CoreNFC/CoreNFC.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AFNFCInputType) {
  AFNFCInputTypeText = 0,
  AFNFCInputTypeLink = 1
};

@interface NFCMessageBuilder : NSObject
+ (NFCNDEFMessage *)messageForType:(AFNFCInputType)type
                             value:(NSString *)value
                             error:(NSError **)error;
@end