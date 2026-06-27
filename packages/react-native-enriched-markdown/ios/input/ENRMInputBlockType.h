#pragma once

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Horizontal indent added per nesting depth (points).
static const CGFloat ENRMListIndentPerDepth = 18.0;

/// Width reserved for the bullet marker column before the item text (points).
static const CGFloat ENRMListMarkerWidth = 18.0;

/// Paragraph-level block kinds supported by the editor. Unlike inline styles
/// (bold, italic) which apply to character ranges, block styles apply to whole
/// lines and are mutually exclusive per line.
typedef NS_ENUM(NSInteger, ENRMInputBlockType) {
  ENRMInputBlockTypeParagraph = 0,
  ENRMInputBlockTypeUnorderedListItem,
};

/// Custom attributed-string attribute storing the line's ENRMInputBlockType
/// (boxed NSNumber). TextKit migrates attributes across edits, so the block kind
/// survives typing, deletion, and paste without manual range bookkeeping — the
/// same reason inline marks aren't re-derived on every keystroke.
extern NSAttributedStringKey const ENRMBlockTypeAttributeName;

/// Nesting depth (0-based) for list items, boxed as NSNumber. Absent / 0 for
/// top-level items and non-list lines.
extern NSAttributedStringKey const ENRMListDepthAttributeName;

/// Maximum supported list nesting depth (0-based), so indentation stays sane.
static const NSInteger ENRMMaxListDepth = 5;

/// A line range tagged with its block type and depth, used to hand block
/// structure to the serializer (otherwise stateless: plain text + inline ranges).
@interface ENRMBlockRange : NSObject

@property (nonatomic, assign) NSRange range;
@property (nonatomic, assign) ENRMInputBlockType type;
@property (nonatomic, assign) NSInteger depth;

+ (instancetype)rangeWithType:(ENRMInputBlockType)type depth:(NSInteger)depth range:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
