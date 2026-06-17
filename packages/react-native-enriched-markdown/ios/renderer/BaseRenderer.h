#pragma once
#import "NodeRenderer.h"

@class RendererFactory;
@class StyleConfig;

/// Shared base for all node renderers — provides `_rendererFactory` and `_config`
/// as protected ivars and the common designated initializer.
/// Concrete subclasses must implement `renderNode:into:context:`.
@interface BaseRenderer : NSObject {
@protected
  __weak RendererFactory *_rendererFactory;
  StyleConfig *_config;
}

- (instancetype)initWithRendererFactory:(id)rendererFactory config:(id)config;

@end
