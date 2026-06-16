#import "BlockquoteBorder.h"
#import "ParagraphStyleUtils.h"
#import "StyleConfig.h"

// Attribute constants for identifying blockquote segments in text storage
NSString *const BlockquoteDepthAttributeName = @"BlockquoteDepth";
NSString *const BlockquoteBackgroundColorAttributeName = @"BlockquoteBackgroundColor";

@implementation BlockquoteBorder {
  StyleConfig *_config;
}

- (instancetype)initWithConfig:(StyleConfig *)config
{
  if (self = [super init]) {
    _config = config;
  }
  return self;
}

/**
 * Main drawing entry point called by the LayoutManager.
 * Iterates through line fragments to draw backgrounds and borders for nested blockquotes.
 */
- (void)drawBordersForGlyphRange:(NSRange)glyphsToShow
                   layoutManager:(NSLayoutManager *)layoutManager
                   textContainer:(NSTextContainer *)textContainer
                         atPoint:(CGPoint)origin
{
  NSTextStorage *textStorage = layoutManager.textStorage;
  if (!textStorage || textStorage.length == 0) {
    return;
  }

  // Cache configuration values to minimize pointer chasing and method lookups in the loop
  StyleConfig *c = _config;
  CGFloat borderWidth = c.blockquoteBorderWidth;
  CGFloat gapWidth = c.blockquoteGapWidth;
  CGFloat levelSpacing = borderWidth + gapWidth;
  CGFloat containerWidth = textContainer.size.width;
  RCTUIColor *defaultBgColor = c.blockquoteBackgroundColor;
  RCTUIColor *borderColor = c.blockquoteBorderColor;

  UIBezierPath *borderPath = [UIBezierPath bezierPath];

  [layoutManager
      enumerateLineFragmentsForGlyphRange:glyphsToShow
                               usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *container,
                                            NSRange glyphRange, BOOL *stop) {
                                 // Map the glyph range back to character indices to retrieve attributes
                                 NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                                               actualGlyphRange:NULL];
                                 if (charRange.location == NSNotFound || charRange.length == 0) {
                                   return;
                                 }

                                 // Perform a single attribute lookup for the current line fragment
                                 NSDictionary *attrs = [textStorage attributesAtIndex:charRange.location
                                                                       effectiveRange:NULL];
                                 NSNumber *depthNum = attrs[BlockquoteDepthAttributeName];

                                 // If no depth is found, this fragment is not part of a blockquote
                                 if (!depthNum) {
                                   return;
                                 }

                                 NSInteger depth = [depthNum integerValue];
                                 CGFloat baseY = origin.y + rect.origin.y;
                                 BOOL isRTL = ENRMParagraphIsRTL(attrs[NSParagraphStyleAttributeName]);

                                 // 1. Draw Background (Painter's algorithm: draw backgrounds before borders)
                                 RCTUIColor *bgColor = attrs[BlockquoteBackgroundColorAttributeName] ?: defaultBgColor;
                                 if (bgColor && bgColor != [RCTUIColor clearColor]) {
                                   CGContextRef ctx = UIGraphicsGetCurrentContext();
                                   [bgColor setFill];
                                   CGContextFillRect(ctx,
                                                     CGRectMake(origin.x, baseY, containerWidth, rect.size.height));
                                 }

                                 // 2. Aggregate vertical borders into the batch path
                                 for (NSInteger level = 0; level <= depth; level++) {
                                   CGFloat borderX =
                                       isRTL ? origin.x + containerWidth - borderWidth - (levelSpacing * level)
                                             : origin.x + (levelSpacing * level);
                                   CGRect borderRect = CGRectMake(borderX, baseY, borderWidth, rect.size.height);
                                   UIBezierPathAppendPath(borderPath, [UIBezierPath bezierPathWithRect:borderRect]);
                                 }
                               }];

  // 3. Perform a single batch fill for all borders
  if (!borderPath.isEmpty) {
    [borderColor setFill];
    [borderPath fill];
  }
}

@end