#import "ParagraphRenderer.h"
#import "FontUtils.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

@implementation ParagraphRenderer {
  __weak RendererFactory *_rendererFactory;
  StyleConfig *_config;
}

- (instancetype)initWithRendererFactory:(id)rendererFactory config:(id)config
{
  self = [super init];
  if (self) {
    _rendererFactory = rendererFactory;
    _config = (StyleConfig *)config;
  }
  return self;
}

- (void)renderNode:(MarkdownASTNode *)node into:(NSMutableAttributedString *)output context:(RenderContext *)context
{
  // Only set block style if a parent element (e.g. List, Blockquote) hasn't already established one
  BOOL isTopLevel = (context.currentBlockType == BlockTypeNone);

  if (isTopLevel) {
    [context setBlockStyle:BlockTypeParagraph font:_config.paragraphFont color:_config.paragraphColor headingLevel:0];
  }

  NSUInteger start = output.length;
  BOOL shouldApplyMargin =
      (context.currentBlockType == BlockTypeNone || context.currentBlockType == BlockTypeParagraph);

  // Detect if the paragraph is a wrapper for a standalone image to use image-specific spacing
  BOOL isBlockImage = (node.children.count == 1 && ((MarkdownASTNode *)node.children[0]).type == MarkdownNodeTypeImage);
  CGFloat marginTop = isBlockImage ? _config.imageMarginTop : _config.paragraphMarginTop;

  NSUInteger contentStart = start;

  // Handle leading margin for the first element in the document (Index 0 check)
  if (shouldApplyMargin && start == 0) {
    NSUInteger offset = applyBlockSpacingBefore(output, 0, marginTop);
    contentStart += offset;
    start += offset;
  }

  @try {
    [_rendererFactory renderChildrenOfNode:node into:output context:context];
  } @finally {
    if (isTopLevel) {
      [context clearBlockStyle];
    }
  }

  if (output.length <= start)
    return;
  NSRange range = NSMakeRange(start, output.length - start);

  // Avoid standard line height on block images to prevent vertical alignment issues
  if (!isBlockImage) {
    applyLineHeight(output, range, _config.paragraphLineHeight);
  }

  applyTextAlignment(output, range, _config.paragraphTextAlign);

  // Skip marginTop for the first block — already handled by applyBlockSpacingBefore above
  if (shouldApplyMargin && contentStart != 1) {
    NSUInteger inserted = applyParagraphSpacingBefore(output, range, marginTop);
    start += inserted;
  }

  CGFloat marginBottom = 0;
  if (shouldApplyMargin) {
    marginBottom = isBlockImage ? _config.imageMarginBottom : _config.paragraphMarginBottom;
  }
  applyParagraphSpacingAfter(output, start, marginBottom);
}

@end