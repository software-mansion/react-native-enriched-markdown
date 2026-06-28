#import "ENRMUIKit.h"
#import <React/RCTViewComponentView.h>

#ifndef EnrichedMarkdownTextInput_h
#define EnrichedMarkdownTextInput_h

NS_ASSUME_NONNULL_BEGIN

@interface EnrichedMarkdownTextInput : RCTViewComponentView
@property (nonatomic, assign) BOOL blockEmitting;
- (CGSize)measureSize:(CGFloat)maxWidth;
- (nullable NSString *)markdownForSelectedRange;
- (void)pasteMarkdown:(NSString *)markdown;
- (void)replaceSelectedTextWith:(NSString *)text formattingRanges:(NSArray *)ranges;
- (void)scheduleRelayoutIfNeeded;
/// Removes the list marker when Backspace is pressed at the very start of the
/// document on a list line. iOS suppresses the text-change delegate there (nothing
/// precedes the caret), so the text view routes its deleteBackward here. Returns
/// YES if it handled the keystroke (caller should not call super).
- (BOOL)handleBackspaceAtDocumentStart;
@end

NS_ASSUME_NONNULL_END

#endif
