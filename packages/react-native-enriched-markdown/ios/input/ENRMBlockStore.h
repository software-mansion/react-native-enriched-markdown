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

/// Snaps every stored range to the line bounds of its start position.
/// Absorbs edge-typed chars, clips split ranges to first line, drops
/// duplicates. Call after adjustForEditAtLocation: once text is final.
/// Idempotent.
- (void)normalizeToLineBoundsInText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
