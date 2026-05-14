#pragma once
#import "ENRMFeatureFlags.h"
#import "ENRMMathInlineAttachment.h"

#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathEngine.h"

@interface ENRMMathInlineAttachment () {
  CGSize _cachedSize;
  CGFloat _mathAscent;
  CGFloat _mathDescent;
  id<ENRMLaidOutMath> _layout;
}
@end

#endif
