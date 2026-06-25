#import "ParagraphStyleUtils.h"
#import "LastElementUtils.h"
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

ENRMWritingDirectionMode ENRMResolveWritingDirectionMode(NSString *value)
{
  if ([value isEqualToString:@"ltr"]) {
    return ENRMWritingDirectionModeLTR;
  }
  if ([value isEqualToString:@"rtl"]) {
    return ENRMWritingDirectionModeRTL;
  }
  if ([value isEqualToString:@"auto"]) {
    return ENRMWritingDirectionModeAuto;
  }
  return ENRMWritingDirectionModeFirstStrong;
}

static BOOL ENRMIsStrongRTLChar(unichar c)
{
  return (c >= 0x0590 && c <= 0x08FF) || (c >= 0xFB1D && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF);
}

NSWritingDirection ENRMFirstStrongDirection(NSString *text)
{
  NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
  NSUInteger length = text.length;
  for (NSUInteger i = 0; i < length; i++) {
    unichar c = [text characterAtIndex:i];
    if (![letters characterIsMember:c]) {
      continue;
    }
    return ENRMIsStrongRTLChar(c) ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
  }
  return NSWritingDirectionNatural;
}

BOOL ENRMParagraphIsRTL(NSParagraphStyle *style)
{
  if (style && style.baseWritingDirection != NSWritingDirectionNatural) {
    return style.baseWritingDirection == NSWritingDirectionRightToLeft;
  }
  return [[RCTI18nUtil sharedInstance] isRTL];
}

void ENRMApplyWritingDirectionMode(NSMutableAttributedString *output, ENRMWritingDirectionMode mode,
                                   NSWritingDirection layoutDirection)
{
  switch (mode) {
    case ENRMWritingDirectionModeAuto:
      ENRMApplyWritingDirectionToParagraphStyles(output, NSWritingDirectionNatural);
      break;
    case ENRMWritingDirectionModeLTR:
      ENRMApplyWritingDirectionToParagraphStyles(output, NSWritingDirectionLeftToRight);
      break;
    case ENRMWritingDirectionModeRTL:
      ENRMApplyWritingDirectionToParagraphStyles(output, NSWritingDirectionRightToLeft);
      break;
    case ENRMWritingDirectionModeFirstStrong:
      ENRMApplyFirstStrongParagraphDirections(output, layoutDirection);
      break;
  }
}

void ENRMApplyFirstStrongParagraphDirections(NSMutableAttributedString *output, NSWritingDirection fallback)
{
  if (output.length == 0) {
    return;
  }
  NSString *string = output.string;
  NSUInteger length = string.length;
  NSUInteger position = 0;
  while (position < length) {
    NSRange paragraphRange = [string paragraphRangeForRange:NSMakeRange(position, 0)];
    if (NSMaxRange(paragraphRange) <= position) {
      break;
    }
    position = NSMaxRange(paragraphRange);

    NSNumber *isCodeBlock = [output attribute:CodeBlockAttributeName
                                      atIndex:paragraphRange.location
                               effectiveRange:nil];
    if (isCodeBlock.boolValue) {
      continue;
    }

    NSWritingDirection direction = ENRMFirstStrongDirection([string substringWithRange:paragraphRange]);
    if (direction == NSWritingDirectionNatural) {
      direction = fallback;
    }
    if (direction == NSWritingDirectionNatural) {
      continue;
    }

    [output enumerateAttribute:NSParagraphStyleAttributeName
                       inRange:paragraphRange
                       options:0
                    usingBlock:^(NSParagraphStyle *style, NSRange range, BOOL *stop) {
                      if (style != nil && style.baseWritingDirection == direction) {
                        return;
                      }
                      NSMutableParagraphStyle *updated =
                          style ? [style mutableCopy] : [[NSMutableParagraphStyle alloc] init];
                      updated.baseWritingDirection = direction;
                      [output addAttribute:NSParagraphStyleAttributeName value:updated range:range];
                    }];
  }
}

void ENRMApplyWritingDirectionToParagraphStyles(NSMutableAttributedString *output, NSWritingDirection writingDirection)
{
  if (output.length == 0) {
    return;
  }
  [output enumerateAttribute:NSParagraphStyleAttributeName
                     inRange:NSMakeRange(0, output.length)
                     options:0
                  usingBlock:^(NSParagraphStyle *style, NSRange range, BOOL *stop) {
                    if (!style) {
                      return;
                    }
                    NSNumber *isCodeBlock = [output attribute:CodeBlockAttributeName
                                                      atIndex:range.location
                                               effectiveRange:nil];
                    if (isCodeBlock.boolValue) {
                      return;
                    }
                    NSMutableParagraphStyle *mutable = [style mutableCopy];
                    mutable.baseWritingDirection = writingDirection;
                    [output addAttribute:NSParagraphStyleAttributeName value:mutable range:range];
                  }];
}

NSMutableParagraphStyle *getOrCreateParagraphStyle(NSMutableAttributedString *output, NSUInteger index)
{
  NSParagraphStyle *existing = [output attribute:NSParagraphStyleAttributeName atIndex:index effectiveRange:NULL];
  NSMutableParagraphStyle *style = existing ? [existing mutableCopy] : [[NSMutableParagraphStyle alloc] init];
  return style;
}

void applyParagraphSpacingAfter(NSMutableAttributedString *output, NSUInteger start, CGFloat marginBottom)
{
  [output appendAttributedString:kNewlineAttributedString];

  NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, start);
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
  spacerStyle.paragraphSpacing = marginBottom;

  [output addAttribute:NSParagraphStyleAttributeName value:spacerStyle range:NSMakeRange(spacerLocation, 1)];
}

void applyLineHeight(NSMutableAttributedString *output, NSRange range, CGFloat lineHeight)
{
  if (lineHeight <= 0) {
    return;
  }

  NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, range.location);

  style.minimumLineHeight = lineHeight;
  style.maximumLineHeight = lineHeight;

  [output addAttribute:NSParagraphStyleAttributeName value:style range:range];
}

// TODO: Extend baseline offset to every block that calls applyLineHeight (headings, blockquotes,
// code blocks, list items). Keep per-block range scoping — not a whole-document pass like RN Text,
// since blocks can use different line heights. Optionally consolidate into a single post-pass in
// AttributedRenderer; evaluate RN's per-line mode (enableIOSTextBaselineOffsetPerLine) if needed.
void applyBaselineOffset(NSMutableAttributedString *output, NSRange range)
{
  if (range.length == 0) {
    return;
  }

  __block CGFloat maximumLineHeight = 0;
  [output enumerateAttribute:NSParagraphStyleAttributeName
                     inRange:range
                     options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                  usingBlock:^(NSParagraphStyle *paragraphStyle, __unused NSRange subrange, __unused BOOL *stop) {
                    if (!paragraphStyle) {
                      return;
                    }
                    maximumLineHeight = MAX(paragraphStyle.maximumLineHeight, maximumLineHeight);
                  }];

  if (maximumLineHeight <= 0) {
    return;
  }

  __block CGFloat maximumFontLineHeight = 0;
  [output enumerateAttribute:NSFontAttributeName
                     inRange:range
                     options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                  usingBlock:^(UIFont *font, __unused NSRange subrange, __unused BOOL *stop) {
                    if (!font) {
                      return;
                    }
                    maximumFontLineHeight = MAX(UIFontLineHeight(font), maximumFontLineHeight);
                  }];

  if (maximumFontLineHeight <= 0 || maximumLineHeight < maximumFontLineHeight) {
    return;
  }

  CGFloat baseLineOffset = (maximumLineHeight - maximumFontLineHeight) / 2.0;

  [output enumerateAttribute:NSBaselineOffsetAttributeName
                     inRange:range
                     options:0
                  usingBlock:^(NSNumber *existingOffset, NSRange subrange, BOOL *stop) {
                    if (existingOffset != nil) {
                      return;
                    }
                    [output addAttribute:NSBaselineOffsetAttributeName value:@(baseLineOffset) range:subrange];
                  }];
}

void applyTextAlignment(NSMutableAttributedString *output, NSRange range, NSTextAlignment textAlign)
{
  NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, range.location);
  style.alignment = textAlign;
  [output addAttribute:NSParagraphStyleAttributeName value:style range:range];
}

void ENRMApplyLineBreakStrategyToParagraphStyles(NSMutableAttributedString *output,
                                                 NSLineBreakStrategy lineBreakStrategy)
{
  if (output.length == 0) {
    return;
  }
  [output enumerateAttribute:NSParagraphStyleAttributeName
                     inRange:NSMakeRange(0, output.length)
                     options:0
                  usingBlock:^(NSParagraphStyle *value, NSRange range, BOOL *stop) {
                    if (!value) {
                      return;
                    }
                    NSMutableParagraphStyle *mutable = [value mutableCopy];
                    mutable.lineBreakStrategy = lineBreakStrategy;
                    [output addAttribute:NSParagraphStyleAttributeName value:mutable range:range];
                  }];
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
