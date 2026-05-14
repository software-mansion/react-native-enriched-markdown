#import "ENRMIosMathEngine.h"

#if ENRICHED_MARKDOWN_MATH

#import <IosMath/IosMath.h>

@interface ENRMIosMathLayout : NSObject <ENRMLaidOutMath>
@property (nonatomic, strong) MTMathListDisplay *displayList;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat ascent;
@property (nonatomic, assign) CGFloat descent;
@end

@implementation ENRMIosMathLayout

- (void)drawInContext:(CGContextRef)context
{
  // Protocol contract: caller has a top-left flipped CTM (UIKit-style).
  // iosMath's MTMathListDisplay draws in its own bottom-left coordinate
  // system, so flip the CTM back before handing off. macOS callers must
  // flip to top-left before invoking this method.
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, 0, self.ascent + self.descent);
  CGContextScaleCTM(context, 1.0, -1.0);
  self.displayList.position = CGPointMake(0, self.descent);
  [self.displayList draw:context];
  CGContextRestoreGState(context);
}

@end

@implementation ENRMIosMathEngine

- (nullable id<ENRMLaidOutMath>)layoutLatex:(NSString *)latex
                                displayMode:(BOOL)displayMode
                                   fontSize:(CGFloat)fontSize
                                      color:(nullable RCTUIColor *)color
{
  MTMathUILabel *label = [[MTMathUILabel alloc] init];
  label.labelMode = displayMode ? kMTMathUILabelModeDisplay : kMTMathUILabelModeText;
  label.textAlignment = kMTTextAlignmentLeft;
  label.fontSize = fontSize;
  label.latex = latex;
  if (color) {
    label.textColor = color;
  }

#if !TARGET_OS_OSX
  [label layoutIfNeeded];
#else
  // MTMathUILabel on macOS is an NSView; intrinsicContentSize triggers the
  // layout pass that populates `displayList`.
  CGSize labelSize = label.intrinsicContentSize;
  label.frame = CGRectMake(0, 0, labelSize.width, labelSize.height);
  [label layout];
#endif

  MTMathListDisplay *displayList = label.displayList;
  if (!displayList) {
    return nil;
  }

  ENRMIosMathLayout *layout = [[ENRMIosMathLayout alloc] init];
  layout.displayList = displayList;
  layout.width = displayList.width;
  layout.ascent = displayList.ascent;
  layout.descent = displayList.descent;
  return layout;
}

@end

id<ENRMMathEngine> ENRMSharedMathEngine(void)
{
  static id<ENRMMathEngine> sEngine;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ sEngine = [[ENRMIosMathEngine alloc] init]; });
  return sEngine;
}

#endif
