#import "BlockquoteRenderer.h"
#import "BlockquoteBorder.h"
#import "FontUtils.h"
#import "ListItemRenderer.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

static NSString *const kNestedInfoDepthKey = @"depth";
static NSString *const kNestedInfoRangeKey = @"range";

@implementation BlockquoteRenderer

- (id)takeContextSnapshot:(RenderContext *)context
{
  return [context snapshotScope];
}

- (void)renderNodeContent:(MarkdownASTNode *)node
                     into:(NSMutableAttributedString *)output
                  context:(RenderContext *)context
{
  if (output.length > 0 && ![output.string hasSuffix:@"\n"]) {
    [output appendAttributedString:kNewlineAttributedString];
  }

  NSInteger currentDepth = context.blockquoteDepth;
  context.blockquoteDepth = currentDepth + 1;

  [context setBlockStyle:BlockTypeBlockquote
                    font:[_config blockquoteFont]
                   color:[_config blockquoteColor]
            headingLevel:0];

  NSUInteger start = output.length;
  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSUInteger end = output.length;
  if (end <= start) {
    return;
  }

  [self applyStylingAndSpacing:output start:start end:end currentDepth:currentDepth];
}

#pragma mark - Styling and Spacing

- (void)applyStylingAndSpacing:(NSMutableAttributedString *)output
                         start:(NSUInteger)start
                           end:(NSUInteger)end
                  currentDepth:(NSInteger)currentDepth
{
  NSUInteger contentStart = start;
  if (currentDepth == 0) {
    contentStart += applyBlockSpacingBefore(output, start, [_config blockquoteMarginTop]);
  }

  NSRange blockquoteRange = NSMakeRange(contentStart, end - start);
  CGFloat levelSpacing = [_config blockquoteBorderWidth] + [_config blockquoteGapWidth];
  NSArray<NSDictionary *> *nestedInfo = [self collectNestedBlockquotes:output range:blockquoteRange depth:currentDepth];

  // Apply base styling (indentation, depth, background, line height)
  [self applyBaseBlockquoteStyle:output
                           range:blockquoteRange
                           depth:currentDepth
                    levelSpacing:levelSpacing
                 backgroundColor:[_config blockquoteBackgroundColor]
                      lineHeight:[_config blockquoteLineHeight]];

  // Re-apply nested blockquote styles to restore their correct indentation
  // (applyBaseBlockquoteStyle overwrites nested indents with the parent's indent)
  [self reapplyNestedStyles:output nestedInfo:nestedInfo levelSpacing:levelSpacing];

  if (currentDepth == 0) {
    applyBlockSpacingAfter(output, [_config blockquoteMarginBottom]);
  }
}

#pragma mark - Nested Blockquote Handling

- (NSArray<NSDictionary *> *)collectNestedBlockquotes:(NSMutableAttributedString *)output
                                                range:(NSRange)blockquoteRange
                                                depth:(NSInteger)currentDepth
{
  NSMutableArray<NSDictionary *> *nestedInfo = [NSMutableArray array];

  [output
      enumerateAttribute:BlockquoteDepthAttributeName
                 inRange:blockquoteRange
                 options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
              usingBlock:^(id value, NSRange range, BOOL *stop) {
                NSInteger depth = [value integerValue];
                if (value && depth > currentDepth) {
                  [nestedInfo
                      addObject:@{kNestedInfoDepthKey : value, kNestedInfoRangeKey : [NSValue valueWithRange:range]}];
                }
              }];

  return nestedInfo;
}

- (void)applyBaseBlockquoteStyle:(NSMutableAttributedString *)output
                           range:(NSRange)blockquoteRange
                           depth:(NSInteger)currentDepth
                    levelSpacing:(CGFloat)levelSpacing
                 backgroundColor:(RCTUIColor *)backgroundColor
                      lineHeight:(CGFloat)lineHeight
{
  CGFloat totalIndent = [self calculateIndentForDepth:currentDepth levelSpacing:levelSpacing];

  // Depth and background cover the whole range so the border renders behind list content.
  NSMutableDictionary *depthAttributes =
      [NSMutableDictionary dictionaryWithObjectsAndKeys:@(currentDepth), BlockquoteDepthAttributeName, nil];
  if (backgroundColor) {
    depthAttributes[BlockquoteBackgroundColorAttributeName] = backgroundColor;
  }
  [output addAttributes:depthAttributes range:blockquoteRange];

  // List items bake the blockquote indent into their own paragraph style; only non-list content is stamped here.
  [self enumerateNonListRangesIn:output
                           range:blockquoteRange
                      usingBlock:^(NSRange nonListRange) {
                        NSMutableParagraphStyle *paragraphStyle =
                            getOrCreateParagraphStyle(output, nonListRange.location);
                        paragraphStyle.firstLineHeadIndent = totalIndent;
                        paragraphStyle.headIndent = totalIndent;
                        [output addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:nonListRange];
                        applyLineHeight(output, nonListRange, lineHeight);
                      }];
}

- (void)reapplyNestedStyles:(NSMutableAttributedString *)output
                 nestedInfo:(NSArray<NSDictionary *> *)nestedInfo
               levelSpacing:(CGFloat)levelSpacing
{
  // Re-apply indentation to nested blockquotes since applyBaseBlockquoteStyle
  // overwrote them with the parent's indentation
  for (NSDictionary *info in nestedInfo) {
    NSRange nestedRange = [info[kNestedInfoRangeKey] rangeValue];
    NSInteger nestedDepth = [info[kNestedInfoDepthKey] integerValue];
    CGFloat indent = [self calculateIndentForDepth:nestedDepth levelSpacing:levelSpacing];

    [output addAttribute:BlockquoteDepthAttributeName value:info[kNestedInfoDepthKey] range:nestedRange];

    [self enumerateNonListRangesIn:output
                             range:nestedRange
                        usingBlock:^(NSRange nonListRange) {
                          NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, nonListRange.location);
                          style.firstLineHeadIndent = indent;
                          style.headIndent = indent;
                          style.tailIndent = 0;
                          [output addAttribute:NSParagraphStyleAttributeName value:style range:nonListRange];
                        }];
  }
}

- (void)enumerateNonListRangesIn:(NSMutableAttributedString *)output
                           range:(NSRange)range
                      usingBlock:(void (^)(NSRange nonListRange))block
{
  NSMutableArray<NSValue *> *listRanges = [NSMutableArray array];
  [output enumerateAttribute:ListDepthAttribute
                     inRange:range
                     options:0
                  usingBlock:^(id value, NSRange subRange, BOOL *stop) {
                    if (value) {
                      [listRanges addObject:[NSValue valueWithRange:subRange]];
                    }
                  }];

  NSUInteger pos = range.location;
  const NSUInteger end = NSMaxRange(range);
  for (NSValue *val in listRanges) {
    NSRange listRange = [val rangeValue];
    if (pos < listRange.location) {
      block(NSMakeRange(pos, listRange.location - pos));
    }
    pos = MAX(pos, NSMaxRange(listRange));
  }
  if (pos < end) {
    block(NSMakeRange(pos, end - pos));
  }
}

#pragma mark - Helper Methods

- (CGFloat)calculateIndentForDepth:(NSInteger)depth levelSpacing:(CGFloat)levelSpacing
{
  return (depth + 1) * levelSpacing;
}

@end
