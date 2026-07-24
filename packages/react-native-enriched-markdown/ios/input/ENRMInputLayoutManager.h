#pragma once

#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// Layout manager that draws the bullet marker for unordered-list lines into the
/// head-indent column the list block handler reserves. Non-empty list lines are
/// found by scanning the block-type/level attributes the formatter stamps; an
/// empty list line (a just-toggled or just-continued item with no characters to
/// anchor a marker to) is flagged explicitly by the orchestrator via the
/// emptyBullet* properties below.
@interface ENRMInputLayoutManager : NSLayoutManager

/// Depth of the marker to draw on an otherwise-empty list line. Negative disables
/// the empty-line marker.
@property (nonatomic, assign) NSInteger emptyBulletDepth;

/// Whether the empty list line is an ordered item (draws its number instead of a
/// bullet glyph), and the 1-based number to draw.
@property (nonatomic, assign) BOOL emptyBulletOrdered;
@property (nonatomic, assign) NSInteger emptyBulletOrdinal;

/// Character location of the empty list line's paragraph (start of the line).
@property (nonatomic, assign) NSUInteger emptyBulletLocation;

/// Font/color for an empty list line's marker (no character to read them from).
@property (nonatomic, strong, nullable) UIFont *emptyBulletFont;
@property (nonatomic, strong, nullable) UIColor *emptyBulletColor;

/// Whether the empty list line lays out right-to-left (no character to resolve
/// the paragraph direction from), so its marker mirrors to the trailing edge.
@property (nonatomic, assign) BOOL emptyBulletRTL;

/// Leading spacing (points) applied above list items, so the empty-line marker's
/// baseline can account for the spacing that pushes the text down in the fragment.
@property (nonatomic, assign) CGFloat listItemSpacing;

/// Draws the marker for a wholly empty editor. `drawGlyphsForGlyphRange:` is
/// never called when there are zero glyphs, so the text view drives this from its
/// own `drawRect:`. No-op unless an empty list line is flagged.
- (void)drawEmptyEditorBulletWithInset:(UIEdgeInsets)inset;

@end

NS_ASSUME_NONNULL_END
