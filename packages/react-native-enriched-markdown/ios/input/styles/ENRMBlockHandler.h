#pragma once

#import "ENRMBlockRange.h"
#import "ENRMInputFormatter.h"
#include "md4c.h"

NS_ASSUME_NONNULL_BEGIN

/// A block handler owns one ENRMInputBlockType end-to-end: how it styles its
/// paragraph, how it serializes to a markdown line prefix, and which md4c block
/// it parses from. Mirrors ENRMStyleHandler for the inline pipeline. These
/// signatures are designed to cover headings AND list items.
@protocol ENRMBlockHandler <NSObject>

@property (nonatomic, readonly) ENRMInputBlockType blockType;

/// Contribute paragraph-level attributes for a block of this type. Called once
/// per block range during formatting. A heading raises the font size; a list
/// item sets head/tail indents and a marker. May be a no-op.
///
/// @param paragraphStyle Mutable paragraph style to adjust (indents, spacing).
/// @param attributes     Mutable character attributes to add (e.g. font) over
///                       the block range; NSParagraphStyleAttributeName is
///                       applied by the formatter from `paragraphStyle`.
/// @param blockRange     The block being styled (carries type, range, level).
/// @param style          Resolved formatter style (base font, colors).
- (void)applyAttributesToParagraphStyle:(NSMutableParagraphStyle *)paragraphStyle
                             attributes:(NSMutableDictionary<NSAttributedStringKey, id> *)attributes
                             blockRange:(ENRMBlockRange *)blockRange
                                  style:(ENRMInputFormatterStyle *)style;

/// Markdown prefix prepended to each line of the block during serialization,
/// e.g. @"# " for an H1 or @"- " for a bullet. Returns @"" when the block needs
/// no prefix. Owning the marker here replaces a central serializer switch.
- (NSString *)markdownLinePrefixForBlockRange:(ENRMBlockRange *)blockRange;

/// Whether this handler claims the given md4c block, and at what level. The
/// parser asks each handler in turn so block recognition stays handler-driven
/// (mirroring how kSupportedSpans maps inline spans). A heading handler matches
/// MD_BLOCK_H and reads MD_BLOCK_H_DETAIL.level into outLevel.
///
/// @param md4cType The md4c block type entered.
/// @param detail   md4c's per-block detail pointer (may be NULL).
/// @param outLevel On return, the level to record (0 when not applicable). Must
///                 not be NULL.
/// @return YES if this handler owns the block.
- (BOOL)matchesMd4cBlockType:(MD_BLOCKTYPE)md4cType detail:(void *)detail outLevel:(NSInteger *)outLevel;

@end

NS_ASSUME_NONNULL_END
