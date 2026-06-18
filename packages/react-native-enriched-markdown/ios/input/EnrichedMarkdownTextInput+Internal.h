#pragma once

#import "ENRMInputStyledRange.h"
#import "EnrichedMarkdownTextInput.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
  BOOL format;
  BOOL copyAsMarkdown;
} ENRMInputSelectionMenuConfig;

typedef struct {
  BOOL bold;
  BOOL italic;
  BOOL underline;
  BOOL strikethrough;
  BOOL spoiler;
  BOOL link;
} ENRMFormatMenuConfig;

@interface EnrichedMarkdownTextInput (Internal)

- (void)toggleBold;
- (void)toggleItalic;
- (void)toggleUnderline;
- (void)toggleStrikethrough;
- (void)toggleSpoiler;
- (void)toggleInlineStyle:(ENRMInputStyleType)type;
- (void)showLinkPrompt;

- (BOOL)isEffectiveStyleActive:(ENRMInputStyleType)type atPosition:(NSUInteger)position;

- (void)emitContextMenuItemPress:(NSString *)itemText;
- (NSArray<NSString *> *)contextMenuItemTexts;
- (NSArray<NSString *> *)contextMenuItemIcons;
- (ENRMInputSelectionMenuConfig)inputSelectionMenuConfig;
- (ENRMFormatMenuConfig)formatMenuConfig;

#if TARGET_OS_OSX
- (NSMenu *)enrichedMenuForEvent:(NSEvent *)event defaultMenu:(NSMenu *)menu textView:(NSTextView *)textView;
#endif

@end

NS_ASSUME_NONNULL_END
