#import "ListMarkerDrawer.h"
#import "ENRMUIKit.h"
#import "ListItemRenderer.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
#import "StyleConfig.h"

extern NSString *const ListDepthAttribute;
extern NSString *const ListTypeAttribute;
extern NSString *const ListItemNumberAttribute;
extern NSString *const ListItemMarkerStartAttribute;
extern NSString *const TaskItemAttribute;
extern NSString *const TaskCheckedAttribute;

@implementation ListMarkerDrawer {
  StyleConfig *_config;
}

- (instancetype)initWithConfig:(StyleConfig *)config
{
  if (self = [super init]) {
    _config = config;
  }
  return self;
}

- (void)drawMarkersForGlyphRange:(NSRange)glyphsToShow
                   layoutManager:(NSLayoutManager *)layoutManager
                   textContainer:(NSTextContainer *)textContainer
                         atPoint:(CGPoint)origin
{
  NSTextStorage *storage = layoutManager.textStorage;
  if (!storage || storage.length == 0)
    return;

  CGFloat gap = [_config effectiveListGapWidth];
  NSMutableSet *drawnParagraphs = [NSMutableSet set];

  [layoutManager
      enumerateLineFragmentsForGlyphRange:glyphsToShow
                               usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *container,
                                            NSRange glyphRange, BOOL *stop) {
                                 NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                                               actualGlyphRange:NULL];
                                 if (charRange.location == NSNotFound)
                                   return;

                                 // 1. Fetch all attributes at once for efficiency
                                 NSDictionary *attrs = [storage attributesAtIndex:charRange.location
                                                                   effectiveRange:NULL];
                                 if (!attrs[ListDepthAttribute])
                                   return;
                                 if (![attrs[ListItemMarkerStartAttribute] boolValue])
                                   return;

                                 // 2. Identify the start of the paragraph
                                 NSRange paraRange = [storage.string paragraphRangeForRange:charRange];
                                 if (charRange.location != paraRange.location ||
                                     [drawnParagraphs containsObject:@(paraRange.location)])
                                   return;
                                 [drawnParagraphs addObject:@(paraRange.location)];

                                 BOOL isRTL = ENRMParagraphIsRTL(attrs[NSParagraphStyleAttributeName]);

                                 CGPoint glyphLoc = [layoutManager locationForGlyphAtIndex:glyphRange.location];
                                 CGFloat baselineY = origin.y + rect.origin.y + glyphLoc.y;
                                 CGFloat markerX;
                                 if (isRTL) {
                                   markerX = origin.x + usedRect.origin.x + usedRect.size.width + gap;
                                 } else {
                                   markerX = origin.x + usedRect.origin.x - gap;
                                 }

                                 // 4. Draw marker based on type
                                 if ([attrs[TaskItemAttribute] boolValue]) {
                                   UIFont *font = attrs[NSFontAttributeName] ?: [self defaultFont];
                                   BOOL checked = [attrs[TaskCheckedAttribute] boolValue];
                                   const CGFloat size = [_config taskListCheckboxSize];
                                   CGFloat checkboxX = isRTL ? markerX + size / 2.0 : markerX - size / 2.0;
                                   [self drawCheckboxAtX:checkboxX
                                                 centerY:baselineY - (font.capHeight / 2.0)
                                                 checked:checked];
                                 } else if ([attrs[ListTypeAttribute] integerValue] == ListTypeUnordered) {
                                   UIFont *font = attrs[NSFontAttributeName] ?: [self defaultFont];
                                   NSInteger depth = [attrs[ListDepthAttribute] integerValue];
                                   [self drawBulletAtX:markerX
                                               centerY:baselineY - (font.xHeight + font.capHeight) / 4.0
                                                 depth:depth];
                                 } else {
                                   [self drawOrderedMarkerAtX:markerX attrs:attrs baselineY:baselineY isRTL:isRTL];
                                 }
                               }];
}

#pragma mark - Drawing Helpers

- (void)drawCheckboxAtX:(CGFloat)x centerY:(CGFloat)y checked:(BOOL)checked
{
  const CGFloat size = [_config taskListCheckboxSize];
  const CGFloat radius = [_config taskListCheckboxBorderRadius];
  const CGRect rect = CGRectMake(x - size / 2.0, y - size / 2.0, size, size);

  [self
      executeDrawing:^(CGContextRef ctx) {
        UIBezierPath *borderPath = UIBezierPathWithRoundedRect(rect, radius);

        if (checked) {
          [[_config taskListCheckedColor] setFill];
          [borderPath fill];

          [self drawCheckmarkInsideRect:rect size:size];
        } else {
          CGFloat lineWidth = MAX(1.0, size * 0.09);
          CGRect insetRect = CGRectInset(rect, lineWidth / 2.0, lineWidth / 2.0);
          UIBezierPath *insetPath = UIBezierPathWithRoundedRect(insetRect, radius);
          insetPath.lineWidth = lineWidth;
          [[_config taskListBorderColor] setStroke];
          [insetPath stroke];
        }
      }
                 atX:x
                   y:y];
}

- (void)drawCheckmarkInsideRect:(CGRect)rect size:(CGFloat)size
{
  const CGFloat inset = size * 0.22;
  const CGFloat verticalMid = CGRectGetMidY(rect);
  const CGFloat horizontalMidOffset = size * 0.05;

  UIBezierPath *checkmark = [UIBezierPath bezierPath];

  [checkmark moveToPoint:CGPointMake(rect.origin.x + inset, verticalMid)];

  BezierPathAddLine(checkmark, CGPointMake(CGRectGetMidX(rect) - horizontalMidOffset, CGRectGetMaxY(rect) - inset));
  BezierPathAddLine(checkmark, CGPointMake(CGRectGetMaxX(rect) - inset, rect.origin.y + inset));

  checkmark.lineWidth = MAX(1.5, size * 0.12);
  BezierPathSetRoundStyle(checkmark);

  [[_config taskListCheckmarkColor] setStroke];
  [checkmark stroke];
}

- (void)drawBulletAtX:(CGFloat)x centerY:(CGFloat)y depth:(NSInteger)depth
{
  CGFloat size = [_config listStyleBulletSize];
  CGRect rect = CGRectMake(x - size / 2.0, y - size / 2.0, size, size);
  [self
      executeDrawing:^(CGContextRef ctx) {
        switch (depth) {
          case 0:
            [[_config listStyleBulletColor] setFill];
            CGContextFillEllipseInRect(ctx, rect);
            break;
          case 1: {
            CGFloat lineWidth = MAX(1.0, size * 0.15);
            [[_config listStyleBulletColor] setStroke];
            CGContextSetLineWidth(ctx, lineWidth);
            CGContextStrokeEllipseInRect(ctx, CGRectInset(rect, lineWidth / 2.0, lineWidth / 2.0));
            break;
          }
          default:
            [[_config listStyleBulletColor] setFill];
            CGContextFillRect(ctx, rect);
            break;
        }
      }
                 atX:x
                   y:y];
}

- (void)drawOrderedMarkerAtX:(CGFloat)boundaryX
                       attrs:(NSDictionary *)attrs
                   baselineY:(CGFloat)baselineY
                       isRTL:(BOOL)isRTL
{
  NSNumber *num = attrs[ListItemNumberAttribute];
  if (!num)
    return;

  NSString *text = isRTL ? [NSString stringWithFormat:@".%ld", (long)num.integerValue]
                         : [NSString stringWithFormat:@"%ld.", (long)num.integerValue];
  UIFont *font = [_config listMarkerFont] ?: [self defaultFont];

  NSDictionary *mAttrs = @{NSFontAttributeName : font, NSForegroundColorAttributeName : [_config listStyleMarkerColor]};
  CGSize size = [text sizeWithAttributes:mAttrs];
  CGFloat drawX = isRTL ? boundaryX : boundaryX - size.width;

  if ([self isValidX:drawX y:baselineY]) {
    [text drawAtPoint:CGPointMake(drawX, baselineY - font.ascender) withAttributes:mAttrs];
  }
}

- (void)executeDrawing:(void (^)(CGContextRef))block atX:(CGFloat)x y:(CGFloat)y
{
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  if (ctx && [self isValidX:x y:y]) {
    CGContextSaveGState(ctx);
    block(ctx);
    CGContextRestoreGState(ctx);
  }
}

- (UIFont *)defaultFont
{
  return [UIFont systemFontOfSize:[_config listStyleFontSize]];
}

- (BOOL)isValidX:(CGFloat)x y:(CGFloat)y
{
  return !isnan(x) && !isinf(x) && !isnan(y) && !isinf(y);
}

@end
