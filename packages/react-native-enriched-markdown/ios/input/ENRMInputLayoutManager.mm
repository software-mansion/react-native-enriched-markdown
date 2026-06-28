#import "ENRMInputLayoutManager.h"
#import "ENRMInputBlockType.h"
#import <UIKit/UIKit.h>

/// Gap between the bullet glyph and the start of the item text.
static const CGFloat kBulletGap = 5.0;

@implementation ENRMInputLayoutManager

- (instancetype)init
{
  if (self = [super init]) {
    _emptyBulletDepth = -1;
  }
  return self;
}

/// Draws the depth-styled bullet (filled dot, ring, then square) centered at
/// (markerX, centerY).
- (void)drawBulletAtX:(CGFloat)markerX centerY:(CGFloat)centerY depth:(NSInteger)depth font:(UIFont *)font color:(UIColor *)color
{
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  if (!ctx || isnan(markerX) || isnan(centerY)) {
    return;
  }
  CGFloat size = MAX(4.0, font.pointSize * 0.30);
  CGRect bulletRect = CGRectMake(markerX - size / 2.0, centerY - size / 2.0, size, size);
  CGContextSaveGState(ctx);
  switch (((depth % 3) + 3) % 3) {
    case 0:
      [color setFill];
      CGContextFillEllipseInRect(ctx, bulletRect);
      break;
    case 1: {
      CGFloat lineWidth = MAX(1.0, size * 0.15);
      [color setStroke];
      CGContextSetLineWidth(ctx, lineWidth);
      CGContextStrokeEllipseInRect(ctx, CGRectInset(bulletRect, lineWidth / 2.0, lineWidth / 2.0));
      break;
    }
    default:
      [color setFill];
      CGContextFillRect(ctx, bulletRect);
      break;
  }
  CGContextRestoreGState(ctx);
}

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(CGPoint)origin
{
  [super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];

  NSTextStorage *storage = self.textStorage;
  NSString *string = storage.string;
  NSMutableSet<NSNumber *> *drawnParagraphs = [NSMutableSet set];

  [self enumerateLineFragmentsForGlyphRange:glyphsToShow
                                 usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *container,
                                              NSRange glyphRange, BOOL *stop) {
                                   NSRange charRange = [self characterRangeForGlyphRange:glyphRange
                                                                        actualGlyphRange:NULL];
                                   if (charRange.location == NSNotFound) {
                                     return;
                                   }

                                   NSRange paraRange = (charRange.location < string.length)
                                                           ? [string paragraphRangeForRange:charRange]
                                                           : NSMakeRange(charRange.location, 0);
                                   if ([drawnParagraphs containsObject:@(paraRange.location)]) {
                                     return;
                                   }

                                   BOOL isAttributedListLine = NO;
                                   NSInteger depth = 0;
                                   if (charRange.location < storage.length) {
                                     NSNumber *type = [storage attribute:ENRMBlockTypeAttributeName
                                                                 atIndex:charRange.location
                                                          effectiveRange:NULL];
                                     if (type && type.integerValue == ENRMInputBlockTypeUnorderedListItem &&
                                         charRange.location == paraRange.location) {
                                       isAttributedListLine = YES;
                                       NSNumber *depthValue = [storage attribute:ENRMListDepthAttributeName
                                                                         atIndex:charRange.location
                                                                  effectiveRange:NULL];
                                       depth = depthValue ? depthValue.integerValue : 0;
                                     }
                                   }

                                   // An empty list line has no character carrying the attribute, so the
                                   // view points us at it explicitly.
                                   BOOL isEmptyListLine = self.emptyBulletDepth >= 0 &&
                                                          charRange.location == self.emptyBulletLocation &&
                                                          !isAttributedListLine;
                                   if (isEmptyListLine) {
                                     depth = self.emptyBulletDepth;
                                   }

                                   if (!isAttributedListLine && !isEmptyListLine) {
                                     return;
                                   }
                                   [drawnParagraphs addObject:@(paraRange.location)];

                                   UIFont *font = nil;
                                   UIColor *color = nil;
                                   if (charRange.location < storage.length) {
                                     font = [storage attribute:NSFontAttributeName
                                                       atIndex:charRange.location
                                                effectiveRange:NULL];
                                     color = [storage attribute:NSForegroundColorAttributeName
                                                        atIndex:charRange.location
                                                 effectiveRange:NULL];
                                   }
                                   if (!font) {
                                     font = [UIFont systemFontOfSize:16];
                                   }
                                   if (!color) {
                                     color = [UIColor labelColor];
                                   }

                                   CGPoint glyphLoc = [self locationForGlyphAtIndex:glyphRange.location];
                                   CGFloat baselineY = origin.y + rect.origin.y + glyphLoc.y;
                                   CGFloat markerX = origin.x + usedRect.origin.x - kBulletGap;
                                   CGFloat centerY = baselineY - (font.xHeight + font.capHeight) / 4.0;
                                   [self drawBulletAtX:markerX centerY:centerY depth:depth font:font color:color];
                                 }];

  // The trailing empty line (including a wholly empty editor) has no glyph
  // fragment — enumerate above skips it — so draw its marker via the extra line
  // fragment when the view has flagged it as an empty list line.
  if (self.emptyBulletDepth >= 0 && self.emptyBulletLocation >= storage.length &&
      self.extraLineFragmentTextContainer != nil) {
    UIFont *font = self.emptyBulletFont ?: [UIFont systemFontOfSize:16];
    UIColor *color = self.emptyBulletColor ?: [UIColor labelColor];
    CGRect used = self.extraLineFragmentUsedRect;
    CGFloat markerX = origin.x + used.origin.x - kBulletGap;
    CGFloat centerY = origin.y + used.origin.y + used.size.height / 2.0;
    [self drawBulletAtX:markerX centerY:centerY depth:self.emptyBulletDepth font:font color:color];
  }
}

- (void)drawEmptyEditorBulletWithInset:(UIEdgeInsets)inset
{
  if (self.emptyBulletDepth < 0) {
    return;
  }
  UIFont *font = self.emptyBulletFont ?: [UIFont systemFontOfSize:16];
  UIColor *color = self.emptyBulletColor ?: [UIColor labelColor];
  CGFloat headIndent = self.emptyBulletDepth * ENRMListIndentPerDepth + ENRMListMarkerWidth;
  CGFloat markerX = inset.left + headIndent - kBulletGap;
  CGFloat centerY = inset.top + font.lineHeight / 2.0;
  [self drawBulletAtX:markerX centerY:centerY depth:self.emptyBulletDepth font:font color:color];
}

@end
