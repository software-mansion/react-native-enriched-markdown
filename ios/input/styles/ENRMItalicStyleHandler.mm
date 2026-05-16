#import "ENRMItalicStyleHandler.h"

@implementation ENRMItalicStyleHandler

- (ENRMInputStyleType)styleType
{
  return ENRMInputStyleTypeEmphasis;
}

- (ENRMStyleMergingConfig *)mergingConfig
{
  return [ENRMStyleMergingConfig emptyConfig];
}

- (UIFontDescriptorSymbolicTraits)fontTraits
{
  return UIFontDescriptorTraitItalic;
}

- (void)applyNonFontAttributesToTextStorage:(NSTextStorage *)storage
                                      range:(NSRange)range
                            formattingRange:(ENRMFormattingRange *)formattingRange
                                      style:(ENRMInputFormatterStyle *)style
{
  RCTUIColor *color = style.italicColor ?: style.baseTextColor;
  [storage addAttribute:NSForegroundColorAttributeName value:color range:range];
}

@end
