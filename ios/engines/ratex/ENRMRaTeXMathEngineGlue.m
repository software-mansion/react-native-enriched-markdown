#import "ENRMFeatureFlags.h"

#if ENRICHED_MARKDOWN_MATH && ENRICHED_MARKDOWN_MATH_ENGINE_RATEX

#import "ENRMMathEngine.h"
#import "ReactNativeEnrichedMarkdown-Swift.h"

@interface ENRMRaTeXLaidOutMath : NSObject <ENRMLaidOutMath>
@property (nonatomic, strong) ENRMRaTeXLayout *layout;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat ascent;
@property (nonatomic, assign) CGFloat descent;
@end

@implementation ENRMRaTeXLaidOutMath
- (void)drawInContext:(CGContextRef)context
{
  [self.layout drawIn:context];
}
@end

@interface ENRMRaTeXEngineGlue : NSObject <ENRMMathEngine>
@end

@implementation ENRMRaTeXEngineGlue

- (nullable id<ENRMLaidOutMath>)layoutLatex:(NSString *)latex
                                displayMode:(BOOL)displayMode
                                   fontSize:(CGFloat)fontSize
                                      color:(nullable RCTUIColor *)color
{
  ENRMRaTeXLayout *layout = [[ENRMRaTeXMathEngine shared] layoutWithLatex:latex
                                                              displayMode:displayMode
                                                                 fontSize:fontSize
                                                                    color:color];
  if (!layout) {
    return nil;
  }
  ENRMRaTeXLaidOutMath *wrapper = [[ENRMRaTeXLaidOutMath alloc] init];
  wrapper.layout = layout;
  wrapper.width = layout.width;
  wrapper.ascent = layout.ascent;
  wrapper.descent = layout.descent;
  return wrapper;
}

@end

id<ENRMMathEngine> ENRMSharedMathEngine(void)
{
  static id<ENRMMathEngine> sEngine;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ sEngine = [[ENRMRaTeXEngineGlue alloc] init]; });
  return sEngine;
}

#endif
