#import "NodeRenderer.h"

@class RendererFactory;
@class StyleConfig;
@class RenderContext;

@interface ListRenderer : NSObject <NodeRenderer>

- (instancetype)initWithRendererFactory:(RendererFactory *)rendererFactory
                                 config:(StyleConfig *)config
                              isOrdered:(BOOL)isOrdered;

@end
