#import "ENRMAccessibilityLabels.h"

@implementation ENRMAccessibilityLabels

+ (instancetype)defaults
{
  ENRMAccessibilityLabels *labels = [[ENRMAccessibilityLabels alloc] init];
  labels.bulletPoint = @"Bullet point";
  labels.nestedBulletPoint = @"Nested bullet point";
  labels.orderedItem = @"List item {n}";
  labels.nestedOrderedItem = @"Nested list item {n}";
  labels.blockquote = @"Blockquote";
  labels.nestedBlockquote = @"Nested blockquote";
  labels.tableRow = @"Row {n}: {content}";
  labels.mathEquation = @"Math: {latex}";
  labels.rotorHeadings = @"Headings";
  labels.rotorLinks = @"Links";
  labels.rotorImages = @"Images";
  return labels;
}

@end
