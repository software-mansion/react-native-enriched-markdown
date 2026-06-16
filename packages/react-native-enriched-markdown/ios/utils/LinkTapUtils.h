#pragma once

#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// Returns the link URL at the tap location, or nil if no link was tapped.
NSString *_Nullable linkURLAtTapLocation(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer);

/// Returns the link URL at the given character range, or nil if none found.
NSString *_Nullable linkURLAtRange(ENRMPlatformTextView *textView, NSRange characterRange);

/// Returns YES if the point (in textView coordinates) is on a link or task list checkbox.
BOOL isPointOnInteractiveElement(ENRMPlatformTextView *textView, CGPoint point);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
