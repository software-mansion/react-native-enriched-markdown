#import "ENRMMathInlineAttachmentShared.h"

#if ENRICHED_MARKDOWN_MATH

@implementation ENRMMathInlineAttachment

#if !TARGET_OS_OSX

- (void)prepareIfNeeded
{
  if (_layout)
    return;

  _layout = [ENRMSharedMathEngine() layoutLatex:self.latex
                                    displayMode:NO
                                       fontSize:self.fontSize
                                          color:self.mathTextColor];
  if (_layout) {
    _mathAscent = _layout.ascent;
    _mathDescent = _layout.descent;
    _cachedSize = CGSizeMake(_layout.width, _mathAscent + _mathDescent);
  }
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

  if (!_layout)
    return nil;

  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.opaque = NO;

  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:_cachedSize format:format];

  id<ENRMLaidOutMath> layout = _layout;
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
    // UIGraphicsImageRenderer's context is already top-left flipped (UIKit
    // convention); the engine's `drawInContext:` contract expects exactly
    // that, so hand the context off directly.
    [layout drawInContext:rendererContext.CGContext];
  }];
}

#endif

@end

#endif
