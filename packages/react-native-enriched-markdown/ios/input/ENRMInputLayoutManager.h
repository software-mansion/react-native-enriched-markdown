#pragma once

#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMInputLayoutManager : NSLayoutManager

/// Draws a bullet on an otherwise-empty list line (a just-toggled or just-created
/// item with no characters to anchor the marker to). Negative depth disables it.
@property (nonatomic, assign) NSInteger emptyBulletDepth;

/// Character location of the empty list line's paragraph (start of the line).
@property (nonatomic, assign) NSUInteger emptyBulletLocation;

/// Font/color for an empty list line's marker (no character to read them from).
@property (nonatomic, strong, nullable) UIFont *emptyBulletFont;
@property (nonatomic, strong, nullable) UIColor *emptyBulletColor;

/// Draws the marker for a wholly empty editor. `drawGlyphsForGlyphRange:` is
/// never called when there are zero glyphs, so the text view drives this from its
/// own `drawRect:`. No-op unless an empty list line is flagged.
- (void)drawEmptyEditorBulletWithInset:(UIEdgeInsets)inset;

@end

NS_ASSUME_NONNULL_END
