#pragma once

#import "ENRMUIKit.h"

@class EnrichedMarkdownTextInput;

NS_ASSUME_NONNULL_BEGIN

@interface ENRMInputTextView : ENRMPlatformTextView
@property (nonatomic, weak, nullable) EnrichedMarkdownTextInput *markdownTextInput;
// Copies the entire content to the system clipboard using the same pasteboard
// format as the user-triggered copy action, without changing the selection.
- (void)copyEntireContents;
@end

NS_ASSUME_NONNULL_END
