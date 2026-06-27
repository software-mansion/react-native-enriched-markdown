#pragma once

#import "ENRMFormattingRange.h"
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ENRMStyleHandler;

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

- (UIFont *)fontForTraits:(UIFontDescriptorSymbolicTraits)traits;

/// Bold, size-scaled font for a heading level (1-3). Level 0 returns the base
/// font unchanged. Heading typography is derived from the base font so it tracks
/// the configured font family and size automatically.
- (UIFont *)baseFontForHeadingLevel:(NSInteger)level;

/// Font combining a heading's base typography (size + bold) with inline traits,
/// so a bold/italic mark inside a heading composes correctly.
- (UIFont *)fontForTraits:(UIFontDescriptorSymbolicTraits)traits headingLevel:(NSInteger)level;

- (void)invalidateFontCache;

@end

@interface ENRMInputFormatter : NSObject

- (nullable id<ENRMStyleHandler>)handlerForStyleType:(ENRMInputStyleType)type;

- (void)applyFormattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
                   toTextView:(ENRMPlatformTextView *)textView
                        style:(ENRMInputFormatterStyle *)style;

@end

NS_ASSUME_NONNULL_END
