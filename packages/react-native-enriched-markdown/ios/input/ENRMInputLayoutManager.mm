#import "ENRMInputLayoutManager.h"
#import "ENRMInputBlockType.h"
#import <UIKit/UIKit.h>

/// Gap between the bullet glyph and the start of the item text.
static const CGFloat kBulletGap = 5.0;

@implementation ENRMInputLayoutManager

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(CGPoint)origin
{
  [super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];

  NSTextStorage *storage = self.textStorage;
  if (storage.length == 0) {
    return;
  }
  NSString *string = storage.string;
  NSMutableSet<NSNumber *> *drawnParagraphs = [NSMutableSet set];

  [self enumerateLineFragmentsForGlyphRange:glyphsToShow
                                 usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *container,
                                              NSRange glyphRange, BOOL *stop) {
                                   NSRange charRange = [self characterRangeForGlyphRange:glyphRange
                                                                        actualGlyphRange:NULL];
                                   if (charRange.location == NSNotFound || charRange.location >= storage.length) {
                                     return;
                                   }

                                   NSNumber *type = [storage attribute:ENRMBlockTypeAttributeName
                                                               atIndex:charRange.location
                                                        effectiveRange:NULL];
                                   if (!type || type.integerValue != ENRMInputBlockTypeUnorderedListItem) {
                                     return;
                                   }

                                   // Draw the marker only on the paragraph's first line fragment.
                                   NSRange paraRange = [string paragraphRangeForRange:charRange];
                                   if (charRange.location != paraRange.location ||
                                       [drawnParagraphs containsObject:@(paraRange.location)]) {
                                     return;
                                   }
                                   [drawnParagraphs addObject:@(paraRange.location)];

                                   NSNumber *depthValue = [storage attribute:ENRMListDepthAttributeName
                                                                     atIndex:charRange.location
                                                              effectiveRange:NULL];
                                   NSInteger depth = depthValue ? depthValue.integerValue : 0;
                                   UIFont *font = [storage attribute:NSFontAttributeName
                                                             atIndex:charRange.location
                                                      effectiveRange:NULL]
                                                      ?: [UIFont systemFontOfSize:16];
                                   UIColor *color = [storage attribute:NSForegroundColorAttributeName
                                                               atIndex:charRange.location
                                                        effectiveRange:NULL]
                                                        ?: [UIColor labelColor];

                                   CGPoint glyphLoc = [self locationForGlyphAtIndex:glyphRange.location];
                                   CGFloat baselineY = origin.y + rect.origin.y + glyphLoc.y;
                                   CGFloat markerX = origin.x + usedRect.origin.x - kBulletGap;
                                   CGFloat centerY = baselineY - (font.xHeight + font.capHeight) / 4.0;
                                   CGFloat size = MAX(4.0, font.pointSize * 0.30);
                                   CGRect bulletRect =
                                       CGRectMake(markerX - size / 2.0, centerY - size / 2.0, size, size);

                                   CGContextRef ctx = UIGraphicsGetCurrentContext();
                                   if (!ctx || isnan(markerX) || isnan(centerY)) {
                                     return;
                                   }
                                   CGContextSaveGState(ctx);
                                   // Vary the glyph by depth: filled dot, ring, then square.
                                   switch (depth % 3) {
                                     case 0:
                                       [color setFill];
                                       CGContextFillEllipseInRect(ctx, bulletRect);
                                       break;
                                     case 1: {
                                       CGFloat lineWidth = MAX(1.0, size * 0.15);
                                       [color setStroke];
                                       CGContextSetLineWidth(ctx, lineWidth);
                                       CGContextStrokeEllipseInRect(
                                           ctx, CGRectInset(bulletRect, lineWidth / 2.0, lineWidth / 2.0));
                                       break;
                                     }
                                     default:
                                       [color setFill];
                                       CGContextFillRect(ctx, bulletRect);
                                       break;
                                   }
                                   CGContextRestoreGState(ctx);
                                 }];
}

@end
