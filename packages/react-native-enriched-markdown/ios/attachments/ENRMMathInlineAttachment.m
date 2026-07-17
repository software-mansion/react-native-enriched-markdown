#import "ENRMMathInlineAttachmentShared.h"

#if ENRICHED_MARKDOWN_MATH

#if __has_include("ReactNativeEnrichedMarkdown-Swift.h")
#import "ReactNativeEnrichedMarkdown-Swift.h"
#elif __has_include(<ReactNativeEnrichedMarkdown/ReactNativeEnrichedMarkdown-Swift.h>)
#import <ReactNativeEnrichedMarkdown/ReactNativeEnrichedMarkdown-Swift.h>
#endif

@implementation ENRMMathInlineAttachment

- (CGFloat)boxHeight
{
#if !TARGET_OS_OSX
  [self prepareIfNeeded];
#endif
  return _cachedSize.height;
}

#if !TARGET_OS_OSX

- (void)prepareIfNeeded
{
  if (_renderResult)
    return;

  RCTUIColor *color = self.mathTextColor ?: [RCTUIColor blackColor];
  ENRMRaTeXRenderResult *result = [ENRMRaTeXBridge parse:self.latex displayMode:NO fontSize:self.fontSize color:color];
  if (!result)
    return;

  _renderResult = result;
  _mathAscent = result.ascent;
  _mathDescent = result.descent;
  _cachedSize = CGSizeMake(ceil(result.width), ceil(result.totalHeight));
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  [self prepareIfNeeded];
  return CGRectMake(0, -_mathDescent, _cachedSize.width, _cachedSize.height);
}

- (UIImage *)imageForBounds:(CGRect)imageBounds
              textContainer:(NSTextContainer *)textContainer
             characterIndex:(NSUInteger)characterIndex
{
  [self prepareIfNeeded];
  if (!_renderResult)
    return nil;

  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.opaque = NO;

  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:_cachedSize format:format];

  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
    CGContextRef ctx = rendererContext.CGContext;
    CGContextSaveGState(ctx);
    [_renderResult drawIn:ctx];
    CGContextRestoreGState(ctx);
  }];
}

#endif

@end

#endif
