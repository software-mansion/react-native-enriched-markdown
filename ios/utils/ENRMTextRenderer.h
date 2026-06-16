#pragma once
#import <Foundation/Foundation.h>

@class AccessibilityInfo;
@class MarkdownASTNode;
@class RenderContext;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

@interface ENRMRenderResult : NSObject
@property (nonatomic, strong) NSMutableAttributedString *attributedText;
@property (nonatomic, strong) RenderContext *context;
@property (nonatomic, strong) AccessibilityInfo *accessibilityInfo;
@property (nonatomic, assign) CGFloat lastElementMarginBottom;
@end

#ifdef __cplusplus
extern "C" {
#endif

ENRMRenderResult *ENRMRenderASTNodes(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config, BOOL allowTrailingMargin,
                                     BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                     NSLineBreakStrategy lineBreakStrategy);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
