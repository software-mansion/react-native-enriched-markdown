#pragma once

#import "ENRMUIKit.h"

@class EnrichedMarkdownTextInput;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kENRMMarkdownPasteboardType;

/// Writes plainText — and, when non-empty, markdown to the private markdown
/// pasteboard type — to the system pasteboard, replacing any existing contents.
/// Callers are responsible for skipping the call when plainText is empty.
void ENRMWriteToPasteboard(NSString *plainText, NSString *_Nullable markdown);

@interface ENRMInputTextView : ENRMPlatformTextView
@property (nonatomic, weak, nullable) EnrichedMarkdownTextInput *markdownTextInput;
@end

NS_ASSUME_NONNULL_END
