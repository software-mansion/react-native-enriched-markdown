#import "ENRMMathFallback.h"

NSAttributedString *ENRMMathFallbackString(NSString *latex, NSString *delimiter, CGFloat fontSize, RCTUIColor *color)
{
  CGFloat size = fontSize > 0 ? fontSize : kENRMMathFallbackDefaultFontSize;
  UIFont *font = [UIFont systemFontOfSize:size];
  NSString *source = [NSString stringWithFormat:@"%@%@%@", delimiter, latex ?: @"", delimiter];
  return [[NSAttributedString alloc] initWithString:source
                                         attributes:@{
                                           NSFontAttributeName : font,
                                           NSForegroundColorAttributeName : color ?: [RCTUIColor blackColor],
                                         }];
}
