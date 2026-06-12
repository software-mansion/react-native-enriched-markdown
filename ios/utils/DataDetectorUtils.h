#pragma once

#import "ENRMUIKit.h"
#import <Foundation/Foundation.h>

#ifdef __cplusplus
#include <string>
#include <vector>
#endif

typedef NS_OPTIONS(NSUInteger, ENRMDataDetectorType) {
  ENRMDataDetectorTypeNone = 0,
  ENRMDataDetectorTypePhoneNumber = 1 << 0,
  ENRMDataDetectorTypeLink = 1 << 1,
  ENRMDataDetectorTypeEmail = 1 << 2,
  ENRMDataDetectorTypeAddress = 1 << 3,
  ENRMDataDetectorTypeDate = 1 << 4,
};

#ifdef __cplusplus
ENRMDataDetectorType ENRMParseDataDetectorTypes(const std::vector<std::string> &types);
#endif

NS_ASSUME_NONNULL_BEGIN

extern NSString *const ENRMDataDetectorTypeAttributeName;
extern NSString *const ENRMDataDetectorDataAttributeName;

/// Runs NSDataDetector on the attributed string and applies `linkURL` +
/// `ENRMDataDetectorTypeAttributeName` to detected entities that don't already
/// have a `linkURL` attribute. Applies link styling (color, underline, font).
/// Returns YES if any entities were detected.
BOOL ENRMApplyDataDetection(NSMutableAttributedString *attributedText, ENRMDataDetectorType types,
                            RCTUIColor *_Nullable linkColor, BOOL linkUnderline, NSString *_Nullable linkFontFamily);

/// Returns the data detector type string for the attribute value at the given
/// index, or nil if not a data-detected entity.
NSString *_Nullable ENRMDataDetectorTypeAtIndex(NSAttributedString *attributedText, NSUInteger index);

/// Returns the JSON-encoded structured data string stored at the given index,
/// or nil if not a data-detected entity.
NSString *_Nullable ENRMDataDetectorDataAtIndex(NSAttributedString *attributedText, NSUInteger index);

/// Result of a data detector tap query. Non-nil type indicates a detected entity.
@interface ENRMDataDetectorTapInfo : NSObject
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly) NSString *dataJson;
@end

/// Given a character index and attributed text, returns tap info if it's a detected
/// entity, or nil if it's a regular link.
ENRMDataDetectorTapInfo *_Nullable ENRMDataDetectorTapInfoAtIndex(NSAttributedString *attributedText,
                                                                  NSUInteger charIndex);

NS_ASSUME_NONNULL_END
