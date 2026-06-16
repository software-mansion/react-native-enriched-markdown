#import "BaseRenderer.h"

extern NSString *const ListDepthAttribute;
extern NSString *const ListTypeAttribute;
extern NSString *const ListItemNumberAttribute;

extern NSString *const TaskItemAttribute;
extern NSString *const TaskCheckedAttribute;
extern NSString *const TaskIndexAttribute;

@interface ListItemRenderer : BaseRenderer <NodeRenderer>
@end
