#pragma once
#import "ENRMUIKit.h"
#import "ParagraphStyleUtils.h"
#import "StyleConfig.h"

@class MarkdownASTNode;

NS_ASSUME_NONNULL_BEGIN

typedef void (^TableLinkPressBlock)(NSString *url);

@interface TableContainerView : RCTUIView

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyTableNode:(MarkdownASTNode *)tableNode;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

@property (nonatomic, strong) StyleConfig *config;

@property (nonatomic, assign) BOOL allowFontScaling;
@property (nonatomic, assign) CGFloat maxFontSizeMultiplier;

@property (nonatomic, copy, nullable) TableLinkPressBlock onLinkPress;
@property (nonatomic, copy, nullable) TableLinkPressBlock onLinkLongPress;

@property (nonatomic, assign) BOOL enableLinkPreview;

@property (nonatomic, assign) ENRMWritingDirectionMode writingDirectionMode;
@property (nonatomic, assign) NSWritingDirection resolvedLayoutDirection;

@property (nonatomic, copy, nullable) NSString *copyLabel;
@property (nonatomic, copy, nullable) NSString *copyAsMarkdownLabel;

@property (nonatomic, readonly) NSUInteger rowCount;

- (void)animateNewRowsFromPreviousCount:(NSUInteger)previousRowCount duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END
