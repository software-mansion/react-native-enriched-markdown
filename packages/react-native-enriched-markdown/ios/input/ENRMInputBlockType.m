#import "ENRMInputBlockType.h"

NSAttributedStringKey const ENRMBlockTypeAttributeName = @"ENRMBlockType";

@implementation ENRMBlockRange

+ (instancetype)rangeWithType:(ENRMInputBlockType)type range:(NSRange)range
{
  ENRMBlockRange *blockRange = [[ENRMBlockRange alloc] init];
  blockRange.type = type;
  blockRange.range = range;
  return blockRange;
}

@end
