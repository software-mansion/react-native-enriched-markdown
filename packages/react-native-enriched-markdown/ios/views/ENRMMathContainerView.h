#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

@class ENRMAccessibilityLabels;

NS_ASSUME_NONNULL_BEGIN

@interface ENRMMathContainerView : RCTUIView

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyLatex:(NSString *)latex;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

@property (nonatomic, strong) StyleConfig *config;
@property (nonatomic, copy, readonly) NSString *cachedLatex;
@property (nonatomic, strong, nullable) ENRMAccessibilityLabels *accessibilityLabels;

@end

NS_ASSUME_NONNULL_END
