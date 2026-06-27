#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Paragraph-level block kinds supported by the editor. Unlike inline styles
/// (bold, italic) which apply to character ranges, block styles apply to whole
/// paragraphs and are mutually exclusive per paragraph.
typedef NS_ENUM(NSInteger, ENRMInputBlockType) {
  ENRMInputBlockTypeParagraph = 0,
  ENRMInputBlockTypeHeading1,
  ENRMInputBlockTypeHeading2,
  ENRMInputBlockTypeHeading3,
};

/// Custom attributed-string attribute storing the paragraph's ENRMInputBlockType
/// (boxed NSNumber). TextKit migrates attributes across edits, so the block kind
/// survives typing, deletion, and paste without manual range bookkeeping — the
/// same reason inline marks aren't re-derived on every keystroke.
extern NSAttributedStringKey const ENRMBlockTypeAttributeName;

/// Heading level (1-3) for a heading block type, or 0 for non-headings.
static inline NSInteger ENRMHeadingLevelForBlockType(ENRMInputBlockType type)
{
  switch (type) {
    case ENRMInputBlockTypeHeading1:
      return 1;
    case ENRMInputBlockTypeHeading2:
      return 2;
    case ENRMInputBlockTypeHeading3:
      return 3;
    default:
      return 0;
  }
}

static inline ENRMInputBlockType ENRMBlockTypeForHeadingLevel(NSInteger level)
{
  switch (level) {
    case 1:
      return ENRMInputBlockTypeHeading1;
    case 2:
      return ENRMInputBlockTypeHeading2;
    case 3:
      return ENRMInputBlockTypeHeading3;
    default:
      return ENRMInputBlockTypeParagraph;
  }
}

/// A paragraph range tagged with its block type. Used to hand block structure to
/// the serializer, which is otherwise stateless (plain text + inline ranges).
@interface ENRMBlockRange : NSObject

@property (nonatomic, assign) NSRange range;
@property (nonatomic, assign) ENRMInputBlockType type;

+ (instancetype)rangeWithType:(ENRMInputBlockType)type range:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
