#import "ContextMenuUtils.h"
#import "ENRMMenuAction.h"
#import "EditMenuUtils.h"
#import "PasteboardUtils.h"
#import "StyleConfig.h"
#include <TargetConditionals.h>

#if TARGET_OS_OSX

static NSString *resolveMenuLabel(NSString *_Nullable label, NSString *fallback)
{
  return label.length > 0 ? label : fallback;
}

NSMenu *_Nullable buildEditMenuForSelection(NSAttributedString *attributedText, NSRange range,
                                            NSString *_Nullable cachedMarkdown, StyleConfig *styleConfig,
                                            NSArray *suggestedActions, NSArray<NSMenuItem *> *_Nullable customItems,
                                            ENRMSelectionMenuConfig selectionMenuConfig)
{
  NSMenu *menu = ([suggestedActions.firstObject isKindOfClass:[NSMenu class]]) ? (NSMenu *)suggestedActions.firstObject
                                                                               : [[NSMenu alloc] initWithTitle:@""];

  if (range.length == 0) {
    return menu;
  }

  NSAttributedString *selectedText = [attributedText attributedSubstringFromRange:range];
  NSString *markdown = markdownForRange(attributedText, range, cachedMarkdown);
  NSArray<NSString *> *imageURLs = imageURLsInRange(attributedText, range);

  // Replace the system Copy item with our enhanced version (copies RTF/HTML/Markdown).
  // This mirrors the iOS behaviour where we replace the standard-edit Copy action.
  NSString *copyTitle = resolveMenuLabel(selectionMenuConfig.copyLabel, @"Copy");
  NSMenuItem *enhancedCopy =
      ENRMCreateMenuItem(copyTitle, ^{ copyAttributedStringToPasteboard(selectedText, markdown, styleConfig); });
  NSInteger systemCopyIndex = [menu indexOfItemWithTarget:nil andAction:@selector(copy:)];
  if (systemCopyIndex != NSNotFound) {
    [menu removeItemAtIndex:systemCopyIndex];
    [menu insertItem:enhancedCopy atIndex:systemCopyIndex];
  } else {
    if (menu.numberOfItems > 0) {
      [menu addItem:[NSMenuItem separatorItem]];
    }
    [menu addItem:enhancedCopy];
  }

  if (selectionMenuConfig.copyAsMarkdown && markdown.length > 0) {
    NSString *copyMarkdownTitle = resolveMenuLabel(selectionMenuConfig.copyAsMarkdownLabel, @"Copy as Markdown");
    [menu addItem:ENRMCreateMenuItem(copyMarkdownTitle, ^{ copyStringToPasteboard(markdown); })];
  }

  if (selectionMenuConfig.copyImageURL && imageURLs.count > 0) {
    NSString *title;
    if (imageURLs.count == 1) {
      title = resolveMenuLabel(selectionMenuConfig.copyImageUrlLabel, @"Copy Image URL");
    } else if (selectionMenuConfig.copyImageUrlsLabel.length > 0) {
      NSString *countString = [@(imageURLs.count) stringValue];
      title = [selectionMenuConfig.copyImageUrlsLabel stringByReplacingOccurrencesOfString:@"{count}"
                                                                                 withString:countString];
    } else {
      title = [NSString stringWithFormat:@"Copy %lu Image URLs", (unsigned long)imageURLs.count];
    }
    [menu addItem:ENRMCreateMenuItem(title, ^{
            NSString *urlsToCopy = [imageURLs componentsJoinedByString:@"\n"];
            copyStringToPasteboard(urlsToCopy);
          })];
  }

  ENRMPrependMenuItems(menu, customItems);

  return menu;
}

#endif