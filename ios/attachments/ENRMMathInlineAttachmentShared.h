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
}
@end

#endif
