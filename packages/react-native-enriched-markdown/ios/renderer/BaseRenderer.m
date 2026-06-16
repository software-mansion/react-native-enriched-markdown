#import "BaseRenderer.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

@implementation BaseRenderer

- (instancetype)initWithRendererFactory:(id)rendererFactory config:(id)config
{
  if (self = [super init]) {
    _rendererFactory = rendererFactory;
    _config = (StyleConfig *)config;
  }
  return self;
}

@end
