#import "AttributedRenderer.h"
#import "CodeBlockBackground.h"
#import "LastElementUtils.h"
#import "MarkdownASTNode.h"
#import "NodeRenderer.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

@implementation AttributedRenderer {
  StyleConfig *_config;
  RendererFactory *_rendererFactory;
  CGFloat _lastElementMarginBottom;
  BOOL _allowTrailingMargin;
}

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super init];
  if (self) {
    _config = config;
    _rendererFactory = [[RendererFactory alloc] initWithConfig:config];
    _lastElementMarginBottom = 0.0;
    _allowTrailingMargin = NO;
  }
  return self;
}

/**
 * Entry point for rendering a Markdown AST.
 * Sets the baseline global style and initiates the recursive traversal.
 */
- (NSMutableAttributedString *)renderRoot:(MarkdownASTNode *)root context:(RenderContext *)context
{
  if (!root)
    return [[NSMutableAttributedString alloc] init];

  // 1. Establish the global baseline style.
  // This ensures that leaf nodes (like Text) have valid attributes if they appear at the root.
  [context setBlockStyle:BlockTypeParagraph font:_config.paragraphFont color:_config.paragraphColor headingLevel:0];

  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] init];

  // 2. Iterate through root children.
  // We skip the 'Root' node itself as it is a container, not a renderable element.
  for (MarkdownASTNode *node in root.children) {
    [self renderNodeRecursive:node into:output context:context];
  }

  // 3. Remove trailing paragraph spacing from last block element
  // Reset lastElementMarginBottom before processing
  _lastElementMarginBottom = 0.0;
  [self removeTrailingSpacing:output];

  // 4. Cleanup global state to prevent side effects in subsequent renders.
  [context clearBlockStyle];

  return output;
}

/// Removes trailing margin spacing while preserving code block padding
- (void)removeTrailingSpacing:(NSMutableAttributedString *)output
{
  if (output.length == 0)
    return;

  // Find the last non-newline character
  NSRange lastContent = [output.string rangeOfCharacterFromSet:[NSCharacterSet.newlineCharacterSet invertedSet]
                                                       options:NSBackwardsSearch];
  if (lastContent.location == NSNotFound)
    return;

  // 1. Capture the Margin Bottom (Scanning from last content to end)
  _lastElementMarginBottom = 0.0;
  for (NSUInteger i = lastContent.location; i < output.length;) {
    NSRange attrRange;
    NSParagraphStyle *style = [output attribute:NSParagraphStyleAttributeName atIndex:i effectiveRange:&attrRange];
    if (style) {
      _lastElementMarginBottom = MAX(_lastElementMarginBottom, style.paragraphSpacing);
    }
    i = NSMaxRange(attrRange);
  }

  // 2. Trim trailing characters
  NSUInteger logicalEnd = NSMaxRange(lastContent);
  BOOL isCodeBlock = isLastElementCodeBlock(output);
  if (isCodeBlock) {
    NSRange codeRange;
    [output attribute:CodeBlockAttributeName atIndex:lastContent.location effectiveRange:&codeRange];
    logicalEnd = NSMaxRange(codeRange);
  }

  if (logicalEnd < output.length) {
    [output deleteCharactersInRange:NSMakeRange(logicalEnd, output.length - logicalEnd)];
  }

  // 3. Zero out internal spacing for the last element (if not a code block)
  if (!isCodeBlock) {
    NSRange styleRange;
    NSParagraphStyle *style = [output attribute:NSParagraphStyleAttributeName
                                        atIndex:lastContent.location
                                 effectiveRange:&styleRange];

    if (style) {
      NSMutableParagraphStyle *mutableStyle = [style mutableCopy];
      mutableStyle.paragraphSpacing = 0;
      mutableStyle.paragraphSpacingBefore = 0;

      if (isLastElementImage(output)) {
        mutableStyle.lineSpacing = 0;
      }

      NSRange safeRange = NSIntersectionRange(styleRange, NSMakeRange(0, output.length));
      [output addAttribute:NSParagraphStyleAttributeName value:mutableStyle range:safeRange];
    }
  }
}

- (void)setAllowTrailingMargin:(BOOL)allow
{
  _allowTrailingMargin = allow;
}

- (CGFloat)getLastElementMarginBottom
{
  return _lastElementMarginBottom;
}

/**
 * Orchestrates the recursive traversal of the AST.
 * If a specialized renderer exists for a node type, it takes full control.
 */
- (void)renderNodeRecursive:(MarkdownASTNode *)node
                       into:(NSMutableAttributedString *)out
                    context:(RenderContext *)context
{
  if (!node)
    return;

  id<NodeRenderer> renderer = [_rendererFactory rendererForNodeType:node.type];

  if (renderer) {
    // Specialized renderers (e.g., Strong, Link, Heading) handle their own sub-trees.
    [renderer renderNode:node into:out context:context];
  } else {
    // Fallback: Default to deep-first traversal for unhandled container nodes.
    for (MarkdownASTNode *child in node.children) {
      [self renderNodeRecursive:child into:out context:context];
    }
  }
}

@end