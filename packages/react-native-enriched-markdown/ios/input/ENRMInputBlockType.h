#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Block-level (paragraph-scoped) element types. A block covers whole lines,
/// unlike inline styles (ENRMInputStyleType) which cover character ranges.
///
/// Paragraph is the default: every line is a paragraph until a block handler
/// claims it. Concrete block types (headings, list items, etc.) are appended
/// here as their handlers are added — each new case must have a matching
/// id<ENRMBlockHandler> registered in ENRMInputFormatter.
typedef NS_ENUM(NSInteger, ENRMInputBlockType) {
  ENRMInputBlockTypeParagraph = 0,
};

/// NSAttributedString attribute carrying the ENRMInputBlockType (boxed NSNumber)
/// of the paragraph a character belongs to. Set by ENRMInputFormatter on the
/// paragraphs a block claims; the next block pass uses it to find and strip the
/// previous pass's styling before re-applying.
extern NSAttributedStringKey const ENRMBlockTypeAttributeName;

/// NSAttributedString attribute carrying the block's integer payload (boxed
/// NSNumber) — e.g. heading level or list depth. See ENRMBlockRange.level.
/// Applied and stripped alongside ENRMBlockTypeAttributeName.
extern NSAttributedStringKey const ENRMBlockLevelAttributeName;

NS_ASSUME_NONNULL_END
