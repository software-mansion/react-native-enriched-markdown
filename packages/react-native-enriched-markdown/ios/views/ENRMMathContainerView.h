#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMMathContainerView : RCTUIView

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyLatex:(NSString *)latex;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

@property (nonatomic, strong) StyleConfig *config;
@property (nonatomic, copy, readonly) NSString *cachedLatex;

// Localized labels for the copy menu. Empty/nil means "use the English default".
@property (nonatomic, copy, nullable) NSString *copyLabel;
@property (nonatomic, copy, nullable) NSString *copyAsMarkdownLabel;

@end

NS_ASSUME_NONNULL_END
