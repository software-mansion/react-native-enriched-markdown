#pragma once
#import "ENRMUIKit.h"
#import <Foundation/Foundation.h>

@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
  BOOL copyAsMarkdown;
  BOOL copyImageURL;
} ENRMSelectionMenuConfig;

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
