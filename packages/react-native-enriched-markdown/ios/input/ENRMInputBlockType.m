#import "ENRMInputBlockType.h"

NSAttributedStringKey const ENRMBlockTypeAttributeName = @"ENRMBlockType";
NSAttributedStringKey const ENRMListDepthAttributeName = @"ENRMListDepth";

@implementation ENRMBlockRange

+ (instancetype)rangeWithType:(ENRMInputBlockType)type depth:(NSInteger)depth range:(NSRange)range
{
  ENRMBlockRange *blockRange = [[ENRMBlockRange alloc] init];
  blockRange.type = type;
  blockRange.depth = depth;
  blockRange.range = range;
  return blockRange;
}

@end
