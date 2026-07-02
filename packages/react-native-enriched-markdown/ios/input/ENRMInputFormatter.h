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

- (UIFont *)fontForTraits:(UIFontDescriptorSymbolicTraits)traits;
- (void)invalidateFontCache;

@end

@interface ENRMInputFormatter : NSObject

- (nullable id<ENRMStyleHandler>)handlerForStyleType:(ENRMInputStyleType)type;
- (nullable id<ENRMBlockHandler>)handlerForBlockType:(ENRMInputBlockType)type;

/// All registered block handlers, for callers that need to interrogate every
/// handler (e.g. the parser asking which block a md4c type maps to).
- (NSArray<id<ENRMBlockHandler>> *)allBlockHandlers;

- (void)applyFormattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
                   toTextView:(ENRMPlatformTextView *)textView
                        style:(ENRMInputFormatterStyle *)style;

/// Applies paragraph-level attributes for each block range via its handler.
/// With no handlers registered (PR1) this is a no-op.
- (void)applyBlockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
              toTextView:(ENRMPlatformTextView *)textView
                   style:(ENRMInputFormatterStyle *)style;

@end

NS_ASSUME_NONNULL_END
