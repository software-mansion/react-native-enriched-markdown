#import "ENRMMathInlineAttachmentShared.h"

#if ENRICHED_MARKDOWN_MATH && TARGET_OS_OSX

@implementation ENRMMathInlineAttachment (macOS)

- (instancetype)init
{
  self = [super init];
  if (self) {
    // NSTextAttachment creates a default NSTextAttachmentCell on macOS.
    // Clear it so NSLayoutManager falls back to the image/bounds properties
    // we set in renderForMacOS.
    self.attachmentCell = nil;
  }
  return self;
}

- (void)renderForMacOS
{
  // The active engine may need to be touched on the main thread (e.g. the
  // iosMath engine creates an MTMathUILabel, an NSView). Bounce if needed.
  if (![NSThread isMainThread]) {
    dispatch_sync(dispatch_get_main_queue(), ^{ [self renderForMacOS]; });
    return;
  }

  _layout = [ENRMSharedMathEngine() layoutLatex:self.latex
                                    displayMode:NO
                                       fontSize:self.fontSize
                                          color:self.mathTextColor];
  if (!_layout) {
    return;
  }

  _mathAscent = _layout.ascent;
  _mathDescent = _layout.descent;
  _cachedSize = CGSizeMake(_layout.width, _mathAscent + _mathDescent);

  // NSImage.lockFocus produces a bottom-left origin Quartz context. The
  // engine `drawInContext:` contract expects top-left (UIKit-flipped), so
  // flip the CTM before delegating. NSLayoutManager draws self.image when
  // attachmentCell is nil — this is the reliable macOS rendering path
  // instead of imageForBounds:textContainer:characterIndex:.
  NSImage *image = [[NSImage alloc] initWithSize:_cachedSize];
  [image lockFocus];
  CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
  CGContextSaveGState(ctx);
  CGContextTranslateCTM(ctx, 0, _cachedSize.height);
  CGContextScaleCTM(ctx, 1.0, -1.0);
  [_layout drawInContext:ctx];
  CGContextRestoreGState(ctx);
  [image unlockFocus];

  self.image = image;
  self.bounds = CGRectMake(0, -_mathDescent, _cachedSize.width, _cachedSize.height);
}

@end

#endif
