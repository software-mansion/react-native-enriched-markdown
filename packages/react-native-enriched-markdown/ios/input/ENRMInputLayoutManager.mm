#import "ENRMInputLayoutManager.h"
#import "ENRMInputBlockType.h"
#import "ParagraphStyleUtils.h"
#import <UIKit/UIKit.h>

@implementation ENRMInputLayoutManager {
  // Reused across draw passes so a marker isn't drawn twice for a wrapped line's
  // continuation fragments. Cleared at the start of each pass instead of freshly
  // allocated, keeping the hot scroll path allocation-free.
  NSMutableSet<NSNumber *> *_drawnParagraphLocations;
}

- (instancetype)init
{
  if (self = [super init]) {
    _emptyBulletDepth = -1;
    _drawnParagraphLocations = [NSMutableSet set];
  }
  return self;
}

/// Draws the depth-styled bullet (filled dot, ring, then square — cycling every
/// three levels) centered at (markerX, centerY). The glyph is sized at ~30% of
/// the text point size so it reads as a marker, not a character.
- (void)drawBulletAtX:(CGFloat)markerX
              centerY:(CGFloat)centerY
                depth:(NSInteger)depth
                 font:(UIFont *)font
                color:(UIColor *)color
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

/// Draws an ordered item's number ("3.") right-aligned so the dot sits a small
/// pad before the text column, sharing the bullet's baseline math.
- (void)drawOrderedMarkerEndingAtX:(CGFloat)markerRight
                         baselineY:(CGFloat)baselineY
                           ordinal:(NSInteger)ordinal
                              font:(UIFont *)font
                             color:(UIColor *)color
{
  NSString *label = [NSString stringWithFormat:@"%ld.", (long)MAX(ordinal, (NSInteger)1)];
  NSDictionary *attrs = @{NSFontAttributeName : font, NSForegroundColorAttributeName : color};
  CGSize size = [label sizeWithAttributes:attrs];
  [label drawAtPoint:CGPointMake(markerRight - size.width, baselineY - font.ascender) withAttributes:attrs];
}

/// RTL counterpart of drawOrderedMarkerEndingAtX:: draws ".3" left-aligned from
/// `markerLeft` so the dot sits a small pad after the (right-anchored) text
/// column. Mirrors the readonly renderer's ListMarkerDrawer.
- (void)drawOrderedMarkerStartingAtX:(CGFloat)markerLeft
                           baselineY:(CGFloat)baselineY
                             ordinal:(NSInteger)ordinal
                                font:(UIFont *)font
                               color:(UIColor *)color
{
  NSString *label = [NSString stringWithFormat:@".%ld", (long)MAX(ordinal, (NSInteger)1)];
  NSDictionary *attrs = @{NSFontAttributeName : font, NSForegroundColorAttributeName : color};
  [label drawAtPoint:CGPointMake(markerLeft, baselineY - font.ascender) withAttributes:attrs];
}

/// Marker anchor for an RTL list line: the text column is anchored a head
/// indent from the trailing (right) edge, so the marker mirrors past it.
/// `leadingOffset` is the same padding+indent that positions the LTR column.
static CGFloat ENRMTrailingMarkerX(CGPoint origin, NSTextContainer *container, CGFloat leadingOffset)
{
  return origin.x + container.size.width - leadingOffset;
}

/// Draws the list marker (ordered "N." / RTL ".N", or a depth-styled bullet) for
/// one list line, resolving its horizontal anchor from the paragraph direction.
/// Shared by the in-text fragment pass and the trailing empty-line pass so the
/// RTL/ordered placement math lives in exactly one place.
- (void)drawListMarkerOrdered:(BOOL)isOrdered
                        depth:(NSInteger)depth
                      ordinal:(NSInteger)ordinal
                          rtl:(BOOL)isRTL
                    baselineY:(CGFloat)baselineY
                       origin:(CGPoint)origin
                     usedRect:(CGRect)usedRect
                    container:(NSTextContainer *)container
                         font:(UIFont *)font
                        color:(UIColor *)color
{
  CGFloat leadingOffset = container.lineFragmentPadding + (depth + 1) * kENRMListIndentPerDepth;
  if (isOrdered) {
    if (isRTL) {
      [self
          drawOrderedMarkerStartingAtX:ENRMTrailingMarkerX(origin, container, leadingOffset) + kENRMListBulletGap / 2.0
                             baselineY:baselineY
                               ordinal:ordinal
                                  font:font
                                 color:color];
    } else {
      [self drawOrderedMarkerEndingAtX:origin.x + usedRect.origin.x - kENRMListBulletGap / 2.0
                             baselineY:baselineY
                               ordinal:ordinal
                                  font:font
                                 color:color];
    }
  } else {
    CGFloat markerX = isRTL ? ENRMTrailingMarkerX(origin, container, leadingOffset) + kENRMListBulletGap
                            : origin.x + usedRect.origin.x - kENRMListBulletGap;
    CGFloat centerY = baselineY - (font.xHeight + font.capHeight) / 4.0;
    [self drawBulletAtX:markerX centerY:centerY depth:depth font:font color:color];
  }
}

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(CGPoint)origin
{
  [super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];

  NSTextStorage *storage = self.textStorage;
  NSString *string = storage.string;
  NSMutableSet<NSNumber *> *drawnParagraphs = _drawnParagraphLocations;
  [drawnParagraphs removeAllObjects];

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
                                   // Wrapped continuation fragments share their line's paragraph; only the
                                   // first fragment of a list line draws a marker.
                                   if ([drawnParagraphs containsObject:@(paraRange.location)]) {
                                     return;
                                   }

                                   BOOL isAttributedListLine = NO;
                                   BOOL isOrdered = NO;
                                   NSInteger depth = 0;
                                   NSInteger ordinal = 1;
                                   if (charRange.location < storage.length) {
                                     NSNumber *type = [storage attribute:ENRMBlockTypeAttributeName
                                                                 atIndex:charRange.location
                                                          effectiveRange:NULL];
                                     if (type && ENRMBlockTypeIsListItem((ENRMInputBlockType)type.integerValue) &&
                                         charRange.location == paraRange.location) {
                                       isAttributedListLine = YES;
                                       isOrdered = type.integerValue == ENRMInputBlockTypeOrderedListItem;
                                       NSNumber *depthValue = [storage attribute:ENRMBlockLevelAttributeName
                                                                         atIndex:charRange.location
                                                                  effectiveRange:NULL];
                                       depth = depthValue ? depthValue.integerValue : 0;
                                       NSNumber *ordinalValue = [storage attribute:ENRMBlockOrdinalAttributeName
                                                                           atIndex:charRange.location
                                                                    effectiveRange:NULL];
                                       ordinal = ordinalValue ? ordinalValue.integerValue : 1;
                                     }
                                   }

                                   // An empty list line has no character carrying the attribute, so the
                                   // orchestrator points us at it explicitly.
                                   BOOL isEmptyListLine = self.emptyBulletDepth >= 0 &&
                                                          charRange.location == self.emptyBulletLocation &&
                                                          !isAttributedListLine;
                                   if (isEmptyListLine) {
                                     depth = self.emptyBulletDepth;
                                     isOrdered = self.emptyBulletOrdered;
                                     ordinal = self.emptyBulletOrdinal;
                                   }

                                   if (!isAttributedListLine && !isEmptyListLine) {
                                     return;
                                   }
                                   [drawnParagraphs addObject:@(paraRange.location)];

                                   UIFont *font = nil;
                                   UIColor *color = nil;
                                   // An empty list line has no character carrying the font/color, so
                                   // use the values the orchestrator supplied for the empty marker.
                                   if (isEmptyListLine) {
                                     font = self.emptyBulletFont;
                                     color = self.emptyBulletColor;
                                   }
                                   if (!font && charRange.location < storage.length) {
                                     font = [storage attribute:NSFontAttributeName
                                                       atIndex:charRange.location
                                                effectiveRange:NULL];
                                   }
                                   if (!color && charRange.location < storage.length) {
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

                                   // An empty line's only glyph is a newline, whose location sits at the
                                   // line's bottom rather than a text baseline — using it would draw the
                                   // marker too low. Derive the baseline from the font ascender (plus the
                                   // leading paragraph spacing, which pushes the text down within the
                                   // fragment) so an empty list line's bullet lands exactly where the
                                   // first typed glyph's bullet will.
                                   CGFloat baselineOffset = isEmptyListLine
                                                                ? self.listItemSpacing + font.ascender
                                                                : [self locationForGlyphAtIndex:glyphRange.location].y;
                                   CGFloat baselineY = origin.y + rect.origin.y + baselineOffset;

                                   // An RTL paragraph anchors its text column to the trailing edge, so
                                   // the marker mirrors to the right of the column (and an ordered
                                   // marker flips to ".N"), matching the readonly ListMarkerDrawer.
                                   BOOL isRTL;
                                   if (isEmptyListLine) {
                                     isRTL = self.emptyBulletRTL;
                                   } else {
                                     isRTL = ENRMParagraphIsRTL([storage attribute:NSParagraphStyleAttributeName
                                                                           atIndex:charRange.location
                                                                    effectiveRange:NULL]);
                                   }

                                   [self drawListMarkerOrdered:isOrdered
                                                         depth:depth
                                                       ordinal:ordinal
                                                           rtl:isRTL
                                                     baselineY:baselineY
                                                        origin:origin
                                                      usedRect:usedRect
                                                     container:container
                                                          font:font
                                                         color:color];
                                 }];

  // The trailing empty line (including a wholly empty editor) has no glyph
  // fragment — the enumeration above skips it — so draw its marker via the extra
  // line fragment when the orchestrator has flagged it as an empty list line.
  if (self.emptyBulletDepth >= 0 && self.emptyBulletLocation >= storage.length &&
      self.extraLineFragmentTextContainer != nil) {
    UIFont *font = self.emptyBulletFont ?: [UIFont systemFontOfSize:16];
    UIColor *color = self.emptyBulletColor ?: [UIColor labelColor];
    CGRect used = self.extraLineFragmentUsedRect;
    NSTextContainer *extraContainer = self.extraLineFragmentTextContainer;
    // Use the same optical center as the in-text marker (baseline minus half the
    // cap/x-height), not the geometric line-box center (font.lineHeight / 2): the
    // two diverge by a font-dependent amount, so a geometric center would shift
    // the empty-line bullet relative to where the first typed glyph's bullet lands
    // (visible with fonts whose ascender/descender are asymmetric).
    CGFloat baselineY = origin.y + used.origin.y + font.ascender;
    [self drawListMarkerOrdered:self.emptyBulletOrdered
                          depth:self.emptyBulletDepth
                        ordinal:self.emptyBulletOrdinal
                            rtl:self.emptyBulletRTL
                      baselineY:baselineY
                         origin:origin
                       usedRect:used
                      container:extraContainer
                           font:font
                          color:color];
  }
}

- (void)drawEmptyEditorBulletWithInset:(UIEdgeInsets)inset
{
  if (self.emptyBulletDepth < 0) {
    return;
  }
  UIFont *font = self.emptyBulletFont ?: [UIFont systemFontOfSize:16];
  UIColor *color = self.emptyBulletColor ?: [UIColor labelColor];
  // Text for a depth-d item starts at (d + 1) * kENRMListIndentPerDepth from the
  // leading edge (see the list block handler); the marker sits a gap before that.
  // In RTL the leading edge is the container's right side, so mirror the anchor.
  CGFloat headIndent = (self.emptyBulletDepth + 1) * kENRMListIndentPerDepth;
  NSTextContainer *container = self.textContainers.firstObject;
  BOOL isRTL = self.emptyBulletRTL && container != nil;
  CGFloat trailingX = inset.left + (container ? container.size.width : 0) - headIndent;
  CGFloat markerX = isRTL ? trailingX + kENRMListBulletGap : inset.left + headIndent - kENRMListBulletGap;
  // Optical center (baseline minus half the cap/x-height) to match the in-text
  // marker, rather than the geometric line-box center; see the extra-line-fragment
  // path. TextKit doesn't apply paragraphSpacingBefore to the first paragraph, so
  // no spacing offset here.
  CGFloat baselineY = inset.top + font.ascender;
  if (self.emptyBulletOrdered) {
    if (isRTL) {
      [self drawOrderedMarkerStartingAtX:(trailingX + kENRMListBulletGap / 2.0)
                               baselineY:baselineY
                                 ordinal:self.emptyBulletOrdinal
                                    font:font
                                   color:color];
    } else {
      [self drawOrderedMarkerEndingAtX:(markerX + kENRMListBulletGap / 2.0)
                             baselineY:baselineY
                               ordinal:self.emptyBulletOrdinal
                                  font:font
                                 color:color];
    }
    return;
  }
  CGFloat centerY = baselineY - (font.xHeight + font.capHeight) / 4.0;
  [self drawBulletAtX:markerX centerY:centerY depth:self.emptyBulletDepth font:font color:color];
}

@end
