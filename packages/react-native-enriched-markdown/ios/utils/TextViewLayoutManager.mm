#import "TextViewLayoutManager.h"
#import "BlockquoteBorder.h"
#import "CodeBackground.h"
#import "CodeBlockBackground.h"
#import "ListMarkerDrawer.h"
#import "RuntimeKeys.h"
#import "StyleConfig.h"
#import <objc/runtime.h>

@implementation TextViewLayoutManager

- (void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow atPoint:(CGPoint)origin
{
  // 1. UIKit standard background drawing
  [super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];

  NSTextStorage *storage = self.textStorage;
  if (!storage || storage.length == 0)
    return;

  // 2. Safely get the container and config
  NSTextContainer *textContainer = [self textContainerForGlyphAtIndex:glyphsToShow.location effectiveRange:NULL];
  if (!textContainer)
    return;

  StyleConfig *config = self.config;
  if (!config)
    return;

  // 3. Draw specialized layers
  // We fetch the objects into local variables FIRST to ensure they don't
  // disappear mid-method if setConfig: is called on another thread.

  CodeBackground *codeBg = [self getCodeBackgroundWithConfig:config];
  [codeBg drawBackgroundsForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];

  CodeBlockBackground *codeBlockBg = [self getCodeBlockBackgroundWithConfig:config];
  [codeBlockBg drawBackgroundsForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];

  BlockquoteBorder *quoteBorder = [self getBlockquoteBorderWithConfig:config];
  [quoteBorder drawBordersForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];

  ListMarkerDrawer *markerDrawer = [self getListMarkerDrawerWithConfig:config];
  [markerDrawer drawMarkersForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];
}

#pragma mark - Safe Property Accessors

// We split these into explicit methods to avoid the 'code 257' pointer corruption
// that can happen with generic 'id' factory blocks.

- (CodeBackground *)getCodeBackgroundWithConfig:(StyleConfig *)config
{
  CodeBackground *obj = objc_getAssociatedObject(self, kCodeBackgroundKey);
  if (!obj) {
    obj = [[CodeBackground alloc] initWithConfig:config];
    objc_setAssociatedObject(self, kCodeBackgroundKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return obj;
}

- (BlockquoteBorder *)getBlockquoteBorderWithConfig:(StyleConfig *)config
{
  BlockquoteBorder *obj = objc_getAssociatedObject(self, kBlockquoteBorderKey);
  if (!obj) {
    obj = [[BlockquoteBorder alloc] initWithConfig:config];
    objc_setAssociatedObject(self, kBlockquoteBorderKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return obj;
}

- (ListMarkerDrawer *)getListMarkerDrawerWithConfig:(StyleConfig *)config
{
  ListMarkerDrawer *obj = objc_getAssociatedObject(self, kListMarkerDrawerKey);
  if (!obj) {
    obj = [[ListMarkerDrawer alloc] initWithConfig:config];
    objc_setAssociatedObject(self, kListMarkerDrawerKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return obj;
}

- (CodeBlockBackground *)getCodeBlockBackgroundWithConfig:(StyleConfig *)config
{
  CodeBlockBackground *obj = objc_getAssociatedObject(self, kCodeBlockBackgroundKey);
  if (!obj) {
    obj = [[CodeBlockBackground alloc] initWithConfig:config];
    objc_setAssociatedObject(self, kCodeBlockBackgroundKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return obj;
}

#pragma mark - Configuration

- (StyleConfig *)config
{
  return objc_getAssociatedObject(self, kStyleConfigKey);
}

- (void)setConfig:(StyleConfig *)config
{
  // We use the same key but clear dependencies first to ensure no stale pointers exist
  objc_setAssociatedObject(self, kCodeBackgroundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(self, kCodeBlockBackgroundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(self, kBlockquoteBorderKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(self, kListMarkerDrawerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  objc_setAssociatedObject(self, kStyleConfigKey, config, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  // Force a full redraw
  [self invalidateDisplayForCharacterRange:NSMakeRange(0, self.textStorage.length)];
}

@end