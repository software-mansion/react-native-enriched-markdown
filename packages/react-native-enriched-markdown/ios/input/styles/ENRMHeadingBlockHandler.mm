#import "ENRMHeadingBlockHandler.h"

@implementation ENRMHeadingBlockHandler

/// Representative block type. One instance serves all six heading levels; the
/// formatter registers it under every heading key explicitly rather than relying
/// on this single value, and applyAttributesToParagraphStyle: dispatches on
/// blockRange.level.
- (ENRMInputBlockType)blockType
{
  return ENRMInputBlockTypeHeading1;
}

- (void)applyAttributesToParagraphStyle:(NSMutableParagraphStyle *)paragraphStyle
                             attributes:(NSMutableDictionary<NSAttributedStringKey, id> *)attributes
                             blockRange:(ENRMBlockRange *)blockRange
                                  style:(ENRMInputFormatterStyle *)style
{
  NSInteger level = blockRange.level;
  if (level < 1 || level > 6) {
    return;
  }

  // The font is merged onto existing inline runs by the formatter (preserving
  // bold/italic traits), so it is set here as the target size/weight only.
  attributes[NSFontAttributeName] = [style headingFontForLevel:level];

  RCTUIColor *headingColor = [style headingColorForLevel:level];
  if (headingColor) {
    attributes[NSForegroundColorAttributeName] = headingColor;
  }
}

- (NSString *)markdownLinePrefixForBlockRange:(ENRMBlockRange *)blockRange
{
  NSInteger level = blockRange.level;
  if (level < 1 || level > 6) {
    return @"";
  }
  // `#` * level followed by a single space, e.g. "### " for an H3.
  NSString *hashes = [@"" stringByPaddingToLength:level withString:@"#" startingAtIndex:0];
  return [hashes stringByAppendingString:@" "];
}

@end
