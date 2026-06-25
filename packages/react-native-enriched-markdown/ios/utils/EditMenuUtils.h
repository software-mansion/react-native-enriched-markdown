#pragma once
#import "ENRMUIKit.h"
#import <Foundation/Foundation.h>

@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
  BOOL copyAsMarkdown;
  BOOL copyImageURL;
  // The owner must keep these strings alive for the duration of the call (the
  // view holds them in strong ivars).
  __unsafe_unretained NSString *_Nullable copyLabel;
  __unsafe_unretained NSString *_Nullable copyAsMarkdownLabel;
  __unsafe_unretained NSString *_Nullable copyImageUrlLabel;
  __unsafe_unretained NSString *_Nullable copyImageUrlsLabel;
  __unsafe_unretained NSArray<NSString *> *_Nullable copyImageUrlPluralTemplates;
} ENRMSelectionMenuConfig;

/// Resolves the "Copy Image URL(s)" menu title for a given image count.
/// Uses the precomputed plural templates (indexed by count, 0..100) when present;
/// counts > 100 use the "other" form (copyImageUrlsLabel). Otherwise the
/// singular/`{count}` templates. All labels are resolved JS-side.
static inline NSString *ENRMResolveImageURLsTitle(ENRMSelectionMenuConfig config, NSUInteger count)
{
  NSArray<NSString *> *templates = config.copyImageUrlPluralTemplates;
  NSString *titleTemplate;
  if (count < templates.count) {
    titleTemplate = templates[count];
  } else if (count == 1) {
    titleTemplate = config.copyImageUrlLabel;
  } else {
    titleTemplate = config.copyImageUrlsLabel;
  }
  return [titleTemplate stringByReplacingOccurrencesOfString:@"{count}" withString:[@(count) stringValue]];
}

#ifdef __cplusplus
extern "C" {
#endif

#if !TARGET_OS_OSX
// TODO: Remove API_AVAILABLE(ios(16.0)) guard when the minimum iOS deployment target in RN is bumped to 16.
// TODO: selectionMenuConfig labels do NOT reach the system "Save to Camera Roll /
// Copy" sheet shown when long-pressing an NSTextAttachment image — UIKit owns
// that sheet end-to-end. Hooking UIContextMenuInteraction on image regions and
// returning a custom UIContextMenuConfiguration would let us relabel those items.
UIMenu *buildEditMenuForSelection(NSAttributedString *attributedText, NSRange range, NSString *_Nullable cachedMarkdown,
                                  StyleConfig *styleConfig, NSArray<UIMenuElement *> *suggestedActions,
                                  NSArray<UIAction *> *_Nullable customActions,
                                  ENRMSelectionMenuConfig selectionMenuConfig) API_AVAILABLE(ios(16.0));
#else
NSMenu *_Nullable buildEditMenuForSelection(NSAttributedString *attributedText, NSRange range,
                                            NSString *_Nullable cachedMarkdown, StyleConfig *styleConfig,
                                            NSArray *suggestedActions, NSArray<NSMenuItem *> *_Nullable customItems,
                                            ENRMSelectionMenuConfig selectionMenuConfig);
#endif

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
