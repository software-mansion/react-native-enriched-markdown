#pragma once

#import "ENRMBlockRange.h"

NS_ASSUME_NONNULL_BEGIN

/// Stores the block-level (paragraph-scoped) ranges for the editor, mirroring
/// ENRMFormattingStore. Unlike inline ranges, block ranges never overlap: at
/// most one block covers any given paragraph, and ranges are kept normalized to
/// whole-line boundaries.
@interface ENRMBlockStore : NSObject

@property (nonatomic, readonly) NSArray<ENRMBlockRange *> *allRanges;

- (void)setRanges:(NSArray<ENRMBlockRange *> *)ranges;
- (void)clearAll;

- (nullable ENRMBlockRange *)blockRangeContainingPosition:(NSUInteger)position;

/// Sets/replaces the block on every paragraph the given range touches, expanding
/// to whole-line boundaries within `text`. Removes any block previously covering
/// those paragraphs.
- (void)setBlockType:(ENRMInputBlockType)type
                level:(NSInteger)level
    forParagraphRange:(NSRange)range
               inText:(NSString *)text;

/// Clears any block on the paragraphs the given range touches (reverting them to
/// the implicit paragraph default).
- (void)removeBlockInParagraphRange:(NSRange)range inText:(NSString *)text;

/// Shifts/clips block ranges to follow a text edit, using the same overlap
/// classification shape as ENRMFormattingStore.
- (void)adjustForEditAtLocation:(NSUInteger)location
                  deletedLength:(NSUInteger)deletedLength
                 insertedLength:(NSUInteger)insertedLength;

/// Re-normalizes every stored range back to the whole-line bounds of the line
/// containing its start (excluding the line terminator). Call after
/// adjustForEditAtLocation: once `text` is final: the edit adjustment
/// deliberately leaves characters inserted at a range's start or end outside
/// the range (matching ENRMFormattingStore's convention), and a newline typed
/// inside a range leaves it spanning two lines. Re-snapping to line bounds
/// re-absorbs edge-typed characters, clips a split range to its first line
/// (the text after the caret becomes a plain paragraph), and drops blocks
/// that a line-join landed on an earlier block's line (first wins).
/// Idempotent: ranges already line-scoped are untouched.
- (void)normalizeToLineBoundsInText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
