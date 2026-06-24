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
  __unsafe_unretained NSString *_Nullable copyImageUrlPluralTemplates;
} ENRMSelectionMenuConfig;

/// Resolves the "Copy Image URL(s)" menu title for a given image count.
/// Uses the precomputed plural templates (count 0..100, wrapping with period 100
/// for larger counts) when present, otherwise the singular/`{count}` templates.
/// Labels are resolved JS-side, so they are always concrete strings.
static inline NSString *ENRMResolveImageURLsTitle(ENRMSelectionMenuConfig config, NSUInteger count)
{
  NSString *titleTemplate = nil;
  NSString *packed = config.copyImageUrlPluralTemplates;
  if (packed.length > 0) {
    NSArray<NSString *> *templates = [packed componentsSeparatedByString:@"\x1f"];
    NSUInteger index = count == 0 ? 0 : (count <= 100 ? count : ((count - 1) % 100) + 1);
    if (index < templates.count) {
      titleTemplate = templates[index];
    }
  }
  if (titleTemplate == nil) {
    titleTemplate = count == 1 ? config.copyImageUrlLabel : config.copyImageUrlsLabel;
  }
  return [titleTemplate stringByReplacingOccurrencesOfString:@"{count}" withString:[@(count) stringValue]];
}

#ifdef __cplusplus
extern "C" {
#endif

#if !TARGET_OS_OSX
// TODO: Remove API_AVAILABLE(ios(16.0)) guard when the minimum iOS deployment target in RN is bumped to 16.
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
