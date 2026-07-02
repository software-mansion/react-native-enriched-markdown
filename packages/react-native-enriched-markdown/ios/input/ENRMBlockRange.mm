#import "ENRMBlockRange.h"

NSAttributedStringKey const ENRMBlockTypeAttributeName = @"ENRMBlockType";
NSAttributedStringKey const ENRMBlockLevelAttributeName = @"ENRMBlockLevel";

@implementation ENRMBlockRange

+ (instancetype)rangeWithType:(ENRMInputBlockType)type range:(NSRange)range
{
  return [self rangeWithType:type range:range level:0];
}

+ (instancetype)rangeWithType:(ENRMInputBlockType)type range:(NSRange)range level:(NSInteger)level
{
  ENRMBlockRange *blockRange = [[ENRMBlockRange alloc] init];
  blockRange.type = type;
  blockRange.range = range;
  blockRange.level = level;
  return blockRange;
}

- (id)copyWithZone:(NSZone *)zone
{
  ENRMBlockRange *copy = [[ENRMBlockRange allocWithZone:zone] init];
  copy.type = _type;
  copy.range = _range;
  copy.level = _level;
  return copy;
}

@end
