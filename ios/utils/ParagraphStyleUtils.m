#import "ParagraphStyleUtils.h"
#import <React/RCTI18nUtil.h>

NSAttributedString *kNewlineAttributedString;
static NSParagraphStyle *kBlockSpacerTemplate;

NSLineBreakStrategy ENRMResolveLineBreakStrategy(NSString *strategy)
{
  if ([strategy isEqualToString:@"standard"]) {
    return NSLineBreakStrategyStandard;
  } else if ([strategy isEqualToString:@"hangul-word"]) {
    return NSLineBreakStrategyHangulWordPriority;
  } else if ([strategy isEqualToString:@"push-out"]) {
    return NSLineBreakStrategyPushOut;
  }
  return NSLineBreakStrategyNone;
}

__attribute__((constructor)) static void initParagraphStyleUtils(void)
{
  kNewlineAttributedString = [[NSAttributedString alloc] initWithString:@"\n"];

  NSMutableParagraphStyle *template = [[NSMutableParagraphStyle alloc] init];
  template.minimumLineHeight = 1;
  template.maximumLineHeight = 1;
  kBlockSpacerTemplate = [template copy];
}

NSWritingDirection currentWritingDirection(void)
{
  BOOL isRTL = [[RCTI18nUtil sharedInstance] isRTL];
  return isRTL ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
}

NSMutableParagraphStyle *getOrCreateParagraphStyle(NSMutableAttributedString *output, NSUInteger index,
                                                   NSLineBreakStrategy lineBreakStrategy)
{
  NSParagraphStyle *existing = [output attribute:NSParagraphStyleAttributeName atIndex:index effectiveRange:NULL];
  NSMutableParagraphStyle *style = existing ? [existing mutableCopy] : [[NSMutableParagraphStyle alloc] init];
  style.baseWritingDirection = currentWritingDirection();
  if (@available(iOS 14.0, *)) {
    style.lineBreakStrategy = lineBreakStrategy;
  }
  return style;
}

void applyParagraphSpacingAfter(NSMutableAttributedString *output, NSUInteger start, CGFloat marginBottom,
                                NSLineBreakStrategy lineBreakStrategy)
{
  [output appendAttributedString:kNewlineAttributedString];

  NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, start, lineBreakStrategy);
  style.paragraphSpacing = marginBottom;

  NSRange range = NSMakeRange(start, output.length - start);
  [output addAttribute:NSParagraphStyleAttributeName value:style range:range];
}

NSUInteger applyParagraphSpacingBefore(NSMutableAttributedString *output, NSRange range, CGFloat marginTop)
{
  if (marginTop <= 0 || range.location == 0)
    return 0;

  NSUInteger prevIdx = range.location - 1;
  if ([output.string characterAtIndex:prevIdx] != '\n')
    return 0;

  NSParagraphStyle *prevStyle = [output attribute:NSParagraphStyleAttributeName atIndex:prevIdx effectiveRange:NULL];

  CGFloat prevMarginBottom = prevStyle.paragraphSpacing;
  if (prevMarginBottom >= marginTop)
    return 0;

  CGFloat extraGap = marginTop - prevMarginBottom;

  NSMutableParagraphStyle *spacerStyle = [kBlockSpacerTemplate mutableCopy];
  spacerStyle.baseWritingDirection = currentWritingDirection();
  spacerStyle.paragraphSpacing = MAX(0, extraGap - 1.0);

  NSDictionary *attrs = @{NSParagraphStyleAttributeName : spacerStyle};
  NSAttributedString *spacer = [[NSAttributedString alloc] initWithString:@"\n" attributes:attrs];

  [output insertAttributedString:spacer atIndex:range.location];
  return 1;
}

NSUInteger applyBlockSpacingBefore(NSMutableAttributedString *output, NSUInteger insertionPoint, CGFloat marginTop)
{
  if (marginTop <= 0) {
    return 0;
  }

  CGFloat spacing = marginTop;

  // At index 0 the spacer \n produces a 1pt line fragment (minimumLineHeight=1)
  // on top of paragraphSpacing. Subtract it so the total equals the desired margin.
  // For non-zero positions the 1pt is intentional inter-block spacing.
  if (insertionPoint == 0) {
    spacing = MAX(0, marginTop - 1.0);
  }

  NSMutableParagraphStyle *spacerStyle = [kBlockSpacerTemplate mutableCopy];
  spacerStyle.baseWritingDirection = currentWritingDirection();
  spacerStyle.paragraphSpacing = spacing;

  NSAttributedString *spacer =
      [[NSAttributedString alloc] initWithString:@"\n" attributes:@{NSParagraphStyleAttributeName : spacerStyle}];

  [output insertAttributedString:spacer atIndex:insertionPoint];
  return 1;
}

void applyBlockSpacingAfter(NSMutableAttributedString *output, CGFloat marginBottom)
{
  if (marginBottom <= 0) {
    return;
  }

  NSUInteger spacerLocation = output.length;
  [output appendAttributedString:kNewlineAttributedString];

  NSMutableParagraphStyle *spacerStyle = [kBlockSpacerTemplate mutableCopy];
  spacerStyle.baseWritingDirection = currentWritingDirection();
  spacerStyle.paragraphSpacing = marginBottom;

  [output addAttribute:NSParagraphStyleAttributeName value:spacerStyle range:NSMakeRange(spacerLocation, 1)];
}

void applyLineHeight(NSMutableAttributedString *output, NSRange range, CGFloat lineHeight,
                     NSLineBreakStrategy lineBreakStrategy)
{
  if (lineHeight <= 0) {
    return;
  }

  NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, range.location, lineBreakStrategy);

  style.minimumLineHeight = lineHeight;
  style.maximumLineHeight = lineHeight;

  [output addAttribute:NSParagraphStyleAttributeName value:style range:range];
}

void applyTextAlignment(NSMutableAttributedString *output, NSRange range, NSTextAlignment textAlign,
                        NSLineBreakStrategy lineBreakStrategy)
{
  NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, range.location, lineBreakStrategy);
  style.alignment = textAlign;
  [output addAttribute:NSParagraphStyleAttributeName value:style range:range];
}

NSTextAlignment textAlignmentFromString(NSString *textAlign)
{
  if ([textAlign isEqualToString:@"left"]) {
    return NSTextAlignmentLeft;
  } else if ([textAlign isEqualToString:@"center"]) {
    return NSTextAlignmentCenter;
  } else if ([textAlign isEqualToString:@"right"]) {
    return NSTextAlignmentRight;
  } else if ([textAlign isEqualToString:@"justify"]) {
    return NSTextAlignmentJustified;
  }
  return NSTextAlignmentNatural;
}
