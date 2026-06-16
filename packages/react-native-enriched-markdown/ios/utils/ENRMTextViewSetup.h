#pragma once
#import "ENRMUIKit.h"
#import "LastElementUtils.h"
#import "StyleConfig.h"
#import "TextViewLayoutManager.h"
#import <React/RCTUtils.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

static inline void ENRMAttachLayoutManager(ENRMPlatformTextView *textView, StyleConfig *_Nullable config)
{
  NSLayoutManager *layoutManager = textView.layoutManager;
  if (layoutManager == nil) {
    return;
  }
  layoutManager.allowsNonContiguousLayout = NO;
  object_setClass(layoutManager, [TextViewLayoutManager class]);
  if (config != nil) {
    [layoutManager setValue:config forKey:@"config"];
  }
}

static inline void ENRMDetachLayoutManager(ENRMPlatformTextView *textView)
{
  NSLayoutManager *layoutManager = textView.layoutManager;
  if (layoutManager != nil && [object_getClass(layoutManager) isEqual:[TextViewLayoutManager class]]) {
    [layoutManager setValue:nil forKey:@"config"];
    object_setClass(layoutManager, [NSLayoutManager class]);
  }
}

static inline CGSize ENRMMeasureMarkdownText(ENRMPlatformTextView *textView, CGFloat maxWidth, StyleConfig *config,
                                             BOOL allowTrailingMargin, CGFloat lastElementMarginBottom)
{
  NSAttributedString *text = ENRMGetAttributedText(textView);
  if (text.length == 0) {
    return CGSizeZero;
  }

  ENRMTextLayoutResult layout = ENRMMeasureTextLayout(textView, maxWidth);

  CGFloat measuredWidth = layout.usedRect.size.width;
  CGFloat measuredHeight = layout.usedRect.size.height;

  // Detect multiline content by checking if the layout produced more than one
  // line fragment. When text wraps, returning the tight usedRect width lets
  // flexShrink narrow the view below maxWidth, causing re-wrap at the narrower
  // width and a height mismatch. Pin to maxWidth for multiline content so Yoga
  // assigns the width the text was actually measured at. Single-line content
  // keeps its tight width for shrink-to-fit behavior.
  NSLayoutManager *layoutManager = textView.layoutManager;
  NSUInteger glyphCount = [layoutManager numberOfGlyphs];
  if (glyphCount > 0) {
    NSRange firstLineRange;
    [layoutManager lineFragmentRectForGlyphAtIndex:0 effectiveRange:&firstLineRange];
    if (NSMaxRange(firstLineRange) < glyphCount) {
      measuredWidth = maxWidth;
    }
  }

  if (!CGRectIsEmpty(layout.extraLineFragmentRect)) {
    measuredHeight -= layout.extraLineFragmentRect.size.height;
  }

  if (isLastElementCodeBlock(text)) {
    measuredHeight += [config codeBlockPadding];
  }

  if (allowTrailingMargin && lastElementMarginBottom > 0) {
    measuredHeight += lastElementMarginBottom;
  }

  CGFloat scale = RCTScreenScale();
  return CGSizeMake(ceil(measuredWidth * scale) / scale, ceil(measuredHeight * scale) / scale);
}

NS_ASSUME_NONNULL_END
