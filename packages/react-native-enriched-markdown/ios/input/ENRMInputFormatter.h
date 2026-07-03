#pragma once

#import "ENRMBlockRange.h"
#import "ENRMFormattingRange.h"
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ENRMStyleHandler;
@protocol ENRMBlockHandler;

@interface ENRMInputLinkVariantStyle : NSObject

@property (nonatomic, copy) NSString *pattern;
@property (nonatomic, strong) RCTUIColor *color;
@property (nonatomic, assign) BOOL underline;
@property (nonatomic, strong, nullable) RCTUIColor *backgroundColor;
@property (nonatomic, strong, nullable) NSRegularExpression *regex;

@end

@interface ENRMInputFormatterStyle : NSObject <NSCopying>

/// Base text properties
@property (nonatomic, strong) UIFont *baseFont;
@property (nonatomic, strong) RCTUIColor *baseTextColor;

/// Bold — color override (nil = inherit baseTextColor)
@property (nonatomic, strong, nullable) RCTUIColor *boldColor;

/// Italic — color override (nil = inherit baseTextColor)
@property (nonatomic, strong, nullable) RCTUIColor *italicColor;

/// Link
@property (nonatomic, strong, nullable) RCTUIColor *linkColor;
@property (nonatomic, assign) BOOL linkUnderline;
@property (nonatomic, strong, nullable) RCTUIColor *linkBackgroundColor;
@property (nonatomic, copy) NSArray<ENRMInputLinkVariantStyle *> *linkVariants;

/// Spoiler
@property (nonatomic, strong, nullable) RCTUIColor *spoilerColor;
@property (nonatomic, strong, nullable) RCTUIColor *spoilerBackgroundColor;

/// Per-level heading config, indexed by level 1-6. A nil/0 entry means the level
/// uses a built-in default derived from the base font. Configured from the
/// `markdownStyle.h1..h6` props.
- (void)setHeadingFontSize:(CGFloat)fontSize forLevel:(NSInteger)level;
- (void)setHeadingFontWeight:(nullable NSString *)fontWeight forLevel:(NSInteger)level;
- (void)setHeadingColor:(nullable RCTUIColor *)color forLevel:(NSInteger)level;

/// Resolved foreground color for a heading level, or nil to inherit baseTextColor.
- (nullable RCTUIColor *)headingColorForLevel:(NSInteger)level;

/// Font for a heading level, built over the base font at the configured size and
/// weight (falling back to a default scale when unset). Does not carry inline
/// traits — those are merged on top in the formatter's font pass.
- (UIFont *)headingFontForLevel:(NSInteger)level;

- (UIFont *)fontForTraits:(UIFontDescriptorSymbolicTraits)traits;
- (void)invalidateFontCache;

@end

@interface ENRMInputFormatter : NSObject

- (nullable id<ENRMStyleHandler>)handlerForStyleType:(ENRMInputStyleType)type;
- (nullable id<ENRMBlockHandler>)handlerForBlockType:(ENRMInputBlockType)type;

- (void)applyFormattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
                   toTextView:(ENRMPlatformTextView *)textView
                        style:(ENRMInputFormatterStyle *)style;

/// Applies paragraph-level attributes for each block range via its handler,
/// after first stripping the attributes applied on the previous pass (so
/// removed blocks don't leave stale paragraph styling behind). With no
/// handlers registered (PR1) this is a no-op.
- (void)applyBlockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
              toTextView:(ENRMPlatformTextView *)textView
                   style:(ENRMInputFormatterStyle *)style;

@end

NS_ASSUME_NONNULL_END
