#import <Foundation/Foundation.h>

@class MarkdownASTNode;
@class RenderContext;

@interface AttributedRenderer : NSObject
- (instancetype)initWithConfig:(id)config;
- (NSMutableAttributedString *)renderRoot:(MarkdownASTNode *)root context:(RenderContext *)context;
- (CGFloat)getLastElementMarginBottom;
- (void)setAllowTrailingMargin:(BOOL)allow;
@end
