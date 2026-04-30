#import "CodeBlockRenderer.h"
#import "CodeBlockBackground.h"
#import "LastElementUtils.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

@implementation CodeBlockRenderer {
  __weak RendererFactory *_rendererFactory;
  StyleConfig *_config;
}

- (instancetype)initWithRendererFactory:(id)rendererFactory config:(id)config
{
  if (self = [super init]) {
    _rendererFactory = rendererFactory;
    _config = (StyleConfig *)config;
  }
  return self;
}

- (void)renderNode:(MarkdownASTNode *)node into:(NSMutableAttributedString *)output context:(RenderContext *)context
{
  [context setBlockStyle:BlockTypeCodeBlock font:[_config codeBlockFont] color:[_config codeBlockColor] headingLevel:0];

  CGFloat padding = [_config codeBlockPadding];
  CGFloat lineHeight = [_config codeBlockLineHeight];
  CGFloat marginTop = [_config codeBlockMarginTop];
  CGFloat marginBottom = [_config codeBlockMarginBottom];

  NSUInteger blockStart = output.length;
  blockStart += applyBlockSpacingBefore(output, blockStart, marginTop);

  // Top Padding: Inserted as a spacer character inside the background area
  [output appendAttributedString:kNewlineAttributedString];
  NSMutableParagraphStyle *topSpacerStyle = [context spacerStyleWithHeight:padding spacing:0];
  topSpacerStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  [output addAttribute:NSParagraphStyleAttributeName value:topSpacerStyle range:NSMakeRange(blockStart, 1)];

  NSUInteger contentStart = output.length;
  @try {
    [_rendererFactory renderChildrenOfNode:node into:output context:context];
  } @finally {
    [context clearBlockStyle];
  }

  NSUInteger contentEnd = output.length;
  if (contentEnd <= contentStart)
    return;

  NSRange contentRange = NSMakeRange(contentStart, contentEnd - contentStart);

  UIFont *codeFont = [_config codeBlockFont];
  RCTUIColor *codeColor = [_config codeBlockColor];
  if (codeColor) {
    [output addAttributes:@{NSFontAttributeName : codeFont, NSForegroundColorAttributeName : codeColor}
                    range:contentRange];
  } else {
    [output addAttribute:NSFontAttributeName value:codeFont range:contentRange];
  }

  if (lineHeight > 0) {
    applyLineHeight(output, contentRange, lineHeight);
  }

  // Code is always LTR regardless of app writing direction
  NSMutableParagraphStyle *baseStyle = [getOrCreateParagraphStyle(output, contentStart) mutableCopy];
  baseStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  baseStyle.alignment = NSTextAlignmentLeft;
  baseStyle.firstLineHeadIndent = padding;
  baseStyle.headIndent = padding;
  baseStyle.tailIndent = -padding;
  [output addAttribute:NSParagraphStyleAttributeName value:baseStyle range:contentRange];

  // Bottom Padding: Inserted as a spacer character inside the background area
  NSUInteger bottomPaddingStart = output.length;
  [output appendAttributedString:kNewlineAttributedString];
  NSMutableParagraphStyle *bottomPaddingStyle = [context spacerStyleWithHeight:padding spacing:0];
  bottomPaddingStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  [output addAttribute:NSParagraphStyleAttributeName value:bottomPaddingStyle range:NSMakeRange(bottomPaddingStart, 1)];

  // Define the range for background rendering (includes padding, excludes margins)
  NSRange backgroundRange = NSMakeRange(blockStart, output.length - blockStart);
  [output addAttribute:CodeBlockAttributeName value:@YES range:backgroundRange];

  // External Margin: Applied outside the background range
  if (marginBottom > 0) {
    applyBlockSpacingAfter(output, marginBottom);
  }
}

@end