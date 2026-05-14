#pragma once
#import "ENRMFeatureFlags.h"
#import "ENRMUIKit.h"

#if ENRICHED_MARKDOWN_MATH

NS_ASSUME_NONNULL_BEGIN

/// The result of laying out a single LaTeX formula. Engines hand one of these
/// back to `ENRMMathInlineAttachment` / `ENRMMathContainerView`, which use
/// the geometry numbers to size the host text run / view and the draw method
/// to paint the glyphs into the host's context.
///
/// `drawInContext:` is documented per-platform: on UIKit (iOS / iPadOS /
/// Mac Catalyst) the caller has already flipped the CTM (Y increases down,
/// origin at the formula's top-left). On AppKit (macOS) the caller has set
/// up a native Quartz context (Y increases up, origin at the formula's
/// bottom-left). Each engine implementation handles its own coordinate
/// translation so callers stay engine-agnostic.
@protocol ENRMLaidOutMath <NSObject>
@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGFloat ascent;
@property (nonatomic, readonly) CGFloat descent;
- (void)drawInContext:(CGContextRef)context;
@end

/// Parses and lays out a LaTeX string. Returns `nil` when the engine cannot
/// render the input — callers fall back to a zero-width attachment so the
/// surrounding text still lays out cleanly.
@protocol ENRMMathEngine <NSObject>
- (nullable id<ENRMLaidOutMath>)layoutLatex:(NSString *)latex
                                displayMode:(BOOL)displayMode
                                   fontSize:(CGFloat)fontSize
                                      color:(nullable RCTUIColor *)color;
@end

/// Process-wide engine accessor. The build wires this to the engine selected
/// via the `ENRICHED_MARKDOWN_MATH_ENGINE` environment variable in the
/// Podfile — by default the iosMath-backed engine, optionally RaTeX. Only
/// one engine ships in the binary; the other source set is excluded by the
/// podspec.
id<ENRMMathEngine> ENRMSharedMathEngine(void);

NS_ASSUME_NONNULL_END

#endif
