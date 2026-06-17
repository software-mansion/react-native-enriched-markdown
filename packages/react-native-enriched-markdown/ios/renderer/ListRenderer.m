#import "ListRenderer.h"
#import "BlockquoteRenderer.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

@implementation ListRenderer {
  __weak RendererFactory *_rendererFactory;
  StyleConfig *_config;
  BOOL _isOrdered;
}

- (instancetype)initWithRendererFactory:(RendererFactory *)factory config:(StyleConfig *)config isOrdered:(BOOL)ordered
{
  if (self = [super init]) {
    _rendererFactory = factory;
    _config = config;
    _isOrdered = ordered;
  }
  return self;
}

- (void)renderNode:(MarkdownASTNode *)node into:(NSMutableAttributedString *)output context:(RenderContext *)context
{
  if (!context)
    return;

  const NSInteger prevDepth = context.listDepth;
  const ListType prevType = context.listType;
  const NSInteger prevNum = context.listItemNumber;

  const NSUInteger startLocation = output.length;
  NSUInteger contentStart = startLocation;

  if (prevDepth == 0) {
    // Apply top margin for root-level list
    contentStart += applyBlockSpacingBefore(output, startLocation, _config.listStyleMarginTop);
  } else if (output.length > 0 && ![output.string hasSuffix:@"\n"]) {
    // Ensure nested lists start on a new line
    [output appendAttributedString:kNewlineAttributedString];
  }

  context.listDepth = prevDepth + 1;
  context.listType = _isOrdered ? ListTypeOrdered : ListTypeUnordered;
  context.listItemNumber = 0; // Reset counter for this specific list level

  [context setBlockStyle:_isOrdered ? BlockTypeOrderedList : BlockTypeUnorderedList
                    font:_config.listStyleFont
                   color:_config.listStyleColor
            headingLevel:0];

  @try {
    [_rendererFactory renderChildrenOfNode:node into:output context:context];
  } @finally {
    context.listDepth = prevDepth;
    context.listType = prevType;
    context.listItemNumber = prevNum;

    if (prevDepth == 0) {
      [context clearBlockStyle];

      // Apply bottom margin for root-level list
      applyBlockSpacingAfter(output, _config.listStyleMarginBottom);
    }
  }
}

@end