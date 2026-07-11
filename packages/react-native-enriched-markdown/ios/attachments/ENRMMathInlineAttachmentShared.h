#pragma once
#import "ENRMFeatureFlags.h"
#import "ENRMMathInlineAttachment.h"

#if ENRICHED_MARKDOWN_MATH

@class ENRMRaTeXRenderResult;

@interface ENRMMathInlineAttachment () {
  CGSize _cachedSize;
  CGFloat _mathAscent;
  CGFloat _mathDescent;
  ENRMRaTeXRenderResult *_renderResult;
  // Visible-source fallback when RaTeX cannot parse the span. A parse failure
  // must NEVER render as an invisible zero-size box — we typeset the original
  // source (delimiters included) in body style instead.
  NSAttributedString *_fallbackSource;
}
@end

#endif
