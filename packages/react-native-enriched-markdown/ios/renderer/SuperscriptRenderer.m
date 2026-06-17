#import "SuperscriptRenderer.h"
#import "BaselineShiftTextAttributes.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

@implementation SuperscriptRenderer

- (void)renderNode:(MarkdownASTNode *)node into:(NSMutableAttributedString *)output context:(RenderContext *)context
{
  NSUInteger start = output.length;
  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSRange range = NSMakeRange(start, output.length - start);
  if (range.length == 0)
    return;

  ENRMApplyBaselineShift(output, range, _config.superscriptFontScale, _config.superscriptBaselineOffsetScale);
}

@end
