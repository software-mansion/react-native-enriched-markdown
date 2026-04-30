#import "ListItemRenderer.h"
#import "ENRMUIKit.h"
#import "LastElementUtils.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

NSString *const ListDepthAttribute = @"ListDepth";
NSString *const ListTypeAttribute = @"ListType";
NSString *const ListItemNumberAttribute = @"ListItemNumber";
NSString *const TaskItemAttribute = @"TaskItem";
NSString *const TaskCheckedAttribute = @"TaskChecked";
NSString *const TaskIndexAttribute = @"TaskIndex";

@interface ListItemRenderer ()
- (void)applyCheckedDecorationsTo:(NSMutableAttributedString *)output
                            range:(NSRange)range
                     nestingLevel:(NSInteger)nestingLevel;
@end

@implementation ListItemRenderer {
  __weak RendererFactory *_rendererFactory;
  StyleConfig *_config;
}

- (instancetype)initWithRendererFactory:(RendererFactory *)factory config:(StyleConfig *)config
{
  if (self = [super init]) {
    _rendererFactory = factory;
    _config = config;
  }
  return self;
}

- (void)renderNode:(MarkdownASTNode *)node into:(NSMutableAttributedString *)output context:(RenderContext *)context
{
  if (!context)
    return;

  context.listItemNumber++;
  const NSInteger currentPosition = context.listItemNumber;
  const NSInteger currentDepth = context.listDepth; // 1-based (1 = top level)

  const BOOL isTask = [node.attributes[@"isTask"] isEqualToString:@"true"];
  const BOOL isChecked = isTask && [node.attributes[@"taskChecked"] isEqualToString:@"true"];
  NSInteger taskIndex = -1;
  if (isTask) {
    taskIndex = context.taskItemCount;
    context.taskItemCount++;
  }

  const NSUInteger startLocation = output.length;

  // Render the actual content of the list item (text, bolding, etc.)
  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  // Ensure every list item ends with a newline to prevent paragraph merging
  if (output.length > startLocation && ![output.string hasSuffix:@"\n"]) {
    [output appendAttributedString:kNewlineAttributedString];
  }

  const NSRange itemRange = NSMakeRange(startLocation, output.length - startLocation);
  if (itemRange.length == 0)
    return;

  // Informs MarkdownAccessibilityElementBuilder about the specific boundaries of this list item
  [context registerListItemRange:itemRange
                        position:currentPosition
                           depth:currentDepth
                       isOrdered:(context.listType == ListTypeOrdered)];

  // currentDepth - 1 handles the horizontal offset for nested lists
  const NSInteger nestingLevel = currentDepth - 1;
  const CGFloat baseMarkerWidth = isTask                                  ? [_config effectiveListMarginLeftForTask]
                                  : (context.listType == ListTypeOrdered) ? [_config effectiveListMarginLeftForNumber]
                                                                          : [_config effectiveListMarginLeftForBullet];

  const CGFloat totalIndent =
      baseMarkerWidth + [_config effectiveListGapWidth] + (nestingLevel * [_config listStyleMarginLeft]);

  const CGFloat lineHeightConfig = [_config listStyleLineHeight];

  // Boxing metadata for attributed string storage
  NSMutableDictionary *metadata = [@{
    ListDepthAttribute : @(nestingLevel),
    ListTypeAttribute : @(context.listType),
    ListItemNumberAttribute : @(currentPosition)
  } mutableCopy];

  if (isTask) {
    metadata[TaskItemAttribute] = @YES;
    metadata[TaskCheckedAttribute] = @(isChecked);
    metadata[TaskIndexAttribute] = @(taskIndex);
  }

  // We enumerate to ensure we don't overwrite styles of nested sub-lists
  // or code blocks that may have already been rendered inside this item.
  [output enumerateAttribute:ListDepthAttribute
                     inRange:itemRange
                     options:0
                  usingBlock:^(id depthAttr, NSRange range, BOOL *stop) {
                    // If a segment already has a Depth attribute higher than our current level,
                    // it belongs to a nested list and we should skip it to preserve its styling.
                    if (depthAttr && [depthAttr integerValue] > nestingLevel) {
                      return;
                    }

                    // Skip code block ranges — CodeBlockRenderer already applied its own
                    // paragraph style (padding, LTR indent). Overwriting would add list
                    // markers ("2.") inside the code block.
                    NSNumber *isCodeBlock = [output attribute:CodeBlockAttributeName
                                                      atIndex:range.location
                                               effectiveRange:nil];
                    if ([isCodeBlock boolValue]) {
                      return;
                    }

                    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
                    style.baseWritingDirection = currentWritingDirection();
                    style.firstLineHeadIndent = totalIndent;
                    style.headIndent = totalIndent;

                    if (lineHeightConfig > 0) {
                      style.minimumLineHeight = lineHeightConfig;
                      style.maximumLineHeight = lineHeightConfig;
                    }

                    NSMutableDictionary *attributesToApply = [metadata mutableCopy];
                    attributesToApply[NSParagraphStyleAttributeName] = style;

                    [output addAttributes:attributesToApply range:range];
                  }];

  if (isTask && isChecked) {
    [self applyCheckedDecorationsTo:output range:itemRange nestingLevel:nestingLevel];
  }
}

- (void)applyCheckedDecorationsTo:(NSMutableAttributedString *)output
                            range:(NSRange)range
                     nestingLevel:(NSInteger)nestingLevel
{
  RCTUIColor *checkedColor = [_config taskListCheckedTextColor];
  BOOL shouldStrikethrough = [_config taskListCheckedStrikethrough];

  if (!checkedColor && !shouldStrikethrough) {
    return;
  }

  NSMutableDictionary *checkedAttrs = [NSMutableDictionary dictionary];

  if (checkedColor) {
    checkedAttrs[NSForegroundColorAttributeName] = checkedColor;
  }

  if (shouldStrikethrough) {
    checkedAttrs[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);

    RCTUIColor *lineColor = checkedColor ?: [_config listStyleColor];
    if (lineColor) {
      checkedAttrs[NSStrikethroughColorAttributeName] = lineColor;
    }
  }

  [output enumerateAttribute:ListDepthAttribute
                     inRange:range
                     options:0
                  usingBlock:^(NSNumber *depth, NSRange segmentRange, BOOL *stop) {
                    BOOL isNestedSubItem = (depth && [depth integerValue] > nestingLevel);
                    if (isNestedSubItem) {
                      return;
                    }

                    // Skip code block ranges — preserve CodeBlockRenderer styles.
                    NSNumber *isCodeBlock = [output attribute:CodeBlockAttributeName
                                                      atIndex:segmentRange.location
                                               effectiveRange:nil];
                    if ([isCodeBlock boolValue]) {
                      return;
                    }

                    [output addAttributes:checkedAttrs range:segmentRange];
                  }];
}

@end