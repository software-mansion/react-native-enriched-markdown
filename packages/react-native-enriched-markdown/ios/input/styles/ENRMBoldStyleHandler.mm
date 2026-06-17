#import "ENRMBoldStyleHandler.h"

@implementation ENRMBoldStyleHandler

- (ENRMInputStyleType)styleType
{
  return ENRMInputStyleTypeStrong;
}

- (ENRMStyleMergingConfig *)mergingConfig
{
  return [ENRMStyleMergingConfig emptyConfig];
}

- (UIFontDescriptorSymbolicTraits)fontTraits
{
  return UIFontDescriptorTraitBold;
}

- (void)applyNonFontAttributesToTextStorage:(NSTextStorage *)storage
                                      range:(NSRange)range
                            formattingRange:(ENRMFormattingRange *)formattingRange
                                      style:(ENRMInputFormatterStyle *)style
{
  RCTUIColor *color = style.boldColor ?: style.baseTextColor;
  [storage addAttribute:NSForegroundColorAttributeName value:color range:range];
}

@end
