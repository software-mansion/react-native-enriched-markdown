#import "SegmentRenderer.h"
#import "ENRMFeatureFlags.h"
#import "ENRMTextRenderer.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RenderedMarkdownSegment.h"

static NSArray *ENRMSplitASTIntoSegments(MarkdownASTNode *root)
{
  NSMutableArray *segments = [NSMutableArray array];
  NSMutableArray *currentTextNodes = [NSMutableArray array];

  for (MarkdownASTNode *child in root.children) {
    if (child.type == MarkdownNodeTypeTable) {
      if (currentTextNodes.count > 0) {
        [segments addObject:[ENRMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      [segments addObject:[ENRMTableSegment segmentWithTableNode:child]];
    }
#if ENRICHED_MARKDOWN_MATH
    else if (child.type == MarkdownNodeTypeLatexMathDisplay) {
#if !TARGET_OS_OSX
      if (currentTextNodes.count > 0) {
        [segments addObject:[ENRMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      NSString *latex = child.children.count > 0 ? child.children.firstObject.content : child.content;
      [segments addObject:[ENRMMathSegment segmentWithLatex:latex ?: @""]];
#else
      // TODO: Fix block math rendering on macOS. Adding ENRMMathContainerView as a
      // segment causes all preceding text segments to become invisible.
#endif
    }
#endif
    else {
      [currentTextNodes addObject:child];
    }
  }

  if (currentTextNodes.count > 0) {
    [segments addObject:[ENRMTextSegment segmentWithNodes:currentTextNodes]];
  }

  return segments;
}

NSArray<ENRMRenderedSegment *> *ENRMRenderSegmentsFromAST(MarkdownASTNode *ast, StyleConfig *config,
                                                          BOOL allowTrailingMargin, BOOL allowFontScaling,
                                                          CGFloat maxFontSizeMultiplier)
{
  NSArray *segments = ENRMSplitASTIntoSegments(ast);
  NSMutableArray<ENRMRenderedSegment *> *renderedSegments = [NSMutableArray array];

  static const uint64_t kTextKindSalt = 0x7465787400000000ULL;  // "text"
  static const uint64_t kTableKindSalt = 0x7461626C00000000ULL; // "tabl"
  static const uint64_t kMathKindSalt = 0x6D61746800000000ULL;  // "math"

  for (id segment in segments) {
    if ([segment isKindOfClass:[ENRMTextSegment class]]) {
      ENRMTextSegment *textSegment = (ENRMTextSegment *)segment;
      ENRMRenderResult *rendered = ENRMRenderASTNodes(textSegment.nodes, config, allowTrailingMargin, allowFontScaling,
                                                      maxFontSizeMultiplier, currentWritingDirection());
      uint64_t signature = ENRMSignatureForNodes(textSegment.nodes) ^ kTextKindSalt;
      [renderedSegments addObject:[ENRMRenderedSegment textSegmentWithResult:rendered signature:signature]];
    } else if ([segment isKindOfClass:[ENRMTableSegment class]]) {
      ENRMTableSegment *tableSegment = (ENRMTableSegment *)segment;
      uint64_t signature = ENRMSignatureForNode(tableSegment.tableNode) ^ kTableKindSalt;
      [renderedSegments addObject:[ENRMRenderedSegment tableSegmentWithSegment:tableSegment signature:signature]];
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathSegment class]]) {
      ENRMMathSegment *mathSegment = (ENRMMathSegment *)segment;
      uint64_t signature = ENRMSignatureForNode(nil) ^ kMathKindSalt;
      NSString *latex = mathSegment.latex ?: @"";
      const char *utf8 = [latex UTF8String];
      while (*utf8) {
        signature ^= (uint8_t)*utf8++;
        signature *= 1099511628211ULL;
      }
      [renderedSegments addObject:[ENRMRenderedSegment mathSegmentWithSegment:mathSegment signature:signature]];
    }
#endif
  }

  return renderedSegments;
}
