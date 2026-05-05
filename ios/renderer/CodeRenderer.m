#import "CodeRenderer.h"
#import "CodeBackground.h"
#import "ENRMUIKit.h"
#import "FontUtils.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"
#import <React/RCTFont.h>

@implementation CodeRenderer {
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

  BlockStyle *blockStyle = [context getBlockStyle];

  RCTUIColor *codeColor = _config.codeColor;

  UIFont *blockFont = cachedFontFromBlockStyle(blockStyle, context);

  UIFontDescriptorSymbolicTraits traits = blockFont.fontDescriptor.symbolicTraits;
  UIFontWeight weight = (traits & UIFontDescriptorTraitBold) ? UIFontWeightBold : UIFontWeightRegular;

  CGFloat codeFontSize = _config.codeFontSize > 0 ? _config.codeFontSize : blockStyle.fontSize;

  NSString *codeFontFamily = _config.codeFontFamily;
  UIFont *codeFont;
  if (codeFontFamily.length > 0) {
    NSString *weightStr = (weight == UIFontWeightBold) ? @"bold" : nil;
    codeFont = [RCTFont updateFont:nil
                        withFamily:codeFontFamily
                              size:@(codeFontSize)
                            weight:weightStr
                             style:nil
                           variant:nil
                   scaleMultiplier:1.0];
  } else {
    codeFont = [UIFont monospacedSystemFontOfSize:codeFontSize weight:weight];
  }

  NSUInteger start = output.length;

  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSRange range = [RenderContext rangeForRenderedContent:output start:start];
  if (range.length > 0) {
    NSDictionary *existingAttributes = [output attributesAtIndex:start effectiveRange:NULL];
    NSMutableDictionary *codeAttributes = [existingAttributes ?: @{} mutableCopy];

    codeAttributes[NSFontAttributeName] = codeFont;
    if (codeColor) {
      codeAttributes[NSForegroundColorAttributeName] = codeColor;
    }
    codeAttributes[CodeAttributeName] = @YES;

    // Store block line height directly for CodeBackground to use
    codeAttributes[@"BlockLineHeight"] = @(UIFontLineHeight(blockFont));

    [output setAttributes:codeAttributes range:range];
  }
}

@end
