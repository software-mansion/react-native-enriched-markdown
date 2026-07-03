#import "ENRMBlockStore.h"
#import "ENRMRangeEditAdjustment.h"

static NSUInteger sortedInsertionIndex(NSArray<ENRMBlockRange *> *ranges, NSUInteger location)
{
  NSUInteger index = 0;
  for (ENRMBlockRange *existing in ranges) {
    if (existing.range.location > location)
      break;
    index++;
  }
  return index;
}

static void removeIndexesInReverse(NSMutableArray *array, NSMutableIndexSet *indexes)
{
  [indexes enumerateIndexesWithOptions:NSEnumerationReverse
                            usingBlock:^(NSUInteger idx, BOOL *stop) { [array removeObjectAtIndex:idx]; }];
}

/// Expands a selection to cover whole paragraphs (line-scoped block boundaries).
/// Clamps unconditionally so out-of-bounds input can't reach
/// paragraphRangeForRange: (which raises on an invalid range).
static NSRange paragraphBoundsForRange(NSRange range, NSString *text)
{
  if (text.length == 0) {
    return NSMakeRange(0, 0);
  }
  NSUInteger location = MIN(range.location, text.length);
  NSUInteger length = MIN(range.length, text.length - location);
  return [text paragraphRangeForRange:NSMakeRange(location, length)];
}

@implementation ENRMBlockStore {
  NSMutableArray<ENRMBlockRange *> *_ranges;
}

- (instancetype)init
{
  if (self = [super init]) {
    _ranges = [NSMutableArray array];
  }
  return self;
}

- (NSArray<ENRMBlockRange *> *)allRanges
{
  return [_ranges copy];
}

// Incoming ranges are trusted to be non-overlapping and line-scoped — the
// parser owns that invariant (md4c block structure never overlaps at the same
// nesting level, and nested containers are not yet mapped). Revisit enforcement
// here if a container block type (list, blockquote) is added.
- (void)setRanges:(NSArray<ENRMBlockRange *> *)ranges
{
  _ranges = [[ranges sortedArrayUsingComparator:^NSComparisonResult(ENRMBlockRange *first, ENRMBlockRange *second) {
    if (first.range.location < second.range.location)
      return NSOrderedAscending;
    if (first.range.location > second.range.location)
      return NSOrderedDescending;
    return NSOrderedSame;
  }] mutableCopy];
}

- (void)clearAll
{
  [_ranges removeAllObjects];
}

- (nullable ENRMBlockRange *)blockRangeContainingPosition:(NSUInteger)position
{
  for (ENRMBlockRange *blockRange in _ranges) {
    if (position >= blockRange.range.location && position < NSMaxRange(blockRange.range)) {
      return blockRange;
    }
  }
  return nil;
}

/// Drops any stored block overlapping `paragraphRange` so a replacement can be
/// inserted cleanly. Blocks are line-scoped and never partially overlap, so a
/// touched block is removed wholesale.
- (void)removeBlocksOverlappingRange:(NSRange)paragraphRange
{
  NSUInteger removeStart = paragraphRange.location;
  NSUInteger removeEnd = NSMaxRange(paragraphRange);
  NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];

  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMBlockRange *existing = _ranges[idx];
    NSUInteger existingStart = existing.range.location;
    NSUInteger existingEnd = NSMaxRange(existing.range);
    if (existingEnd <= removeStart || existingStart >= removeEnd) {
      continue;
    }
    [indexesToRemove addIndex:idx];
  }

  removeIndexesInReverse(_ranges, indexesToRemove);
}

- (void)setBlockType:(ENRMInputBlockType)type
                level:(NSInteger)level
    forParagraphRange:(NSRange)range
               inText:(NSString *)text
{
  NSRange paragraphRange = paragraphBoundsForRange(range, text);
  [self removeBlocksOverlappingRange:paragraphRange];

  if (paragraphRange.length == 0) {
    return;
  }

  ENRMBlockRange *blockRange = [ENRMBlockRange rangeWithType:type range:paragraphRange level:level];
  NSUInteger insertAt = sortedInsertionIndex(_ranges, blockRange.range.location);
  [_ranges insertObject:blockRange atIndex:insertAt];
}

- (void)removeBlockInParagraphRange:(NSRange)range inText:(NSString *)text
{
  NSRange paragraphRange = paragraphBoundsForRange(range, text);
  [self removeBlocksOverlappingRange:paragraphRange];
}

- (void)adjustForEditAtLocation:(NSUInteger)editLocation
                  deletedLength:(NSUInteger)deletedLength
                 insertedLength:(NSUInteger)insertedLength
{
  if (deletedLength == 0 && insertedLength == 0)
    return;

  NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];

  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMBlockRange *blockRange = _ranges[idx];
    ENRMAdjustedRange adjusted = ENRMAdjustRangeForEdit(blockRange.range, editLocation, deletedLength, insertedLength);
    blockRange.range = adjusted.range;
    if (adjusted.shouldRemove) {
      [indexesToRemove addIndex:idx];
    }
  }

  removeIndexesInReverse(_ranges, indexesToRemove);

  NSMutableIndexSet *emptyIndexes = [NSMutableIndexSet indexSet];
  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    if (_ranges[idx].range.length == 0) {
      [emptyIndexes addIndex:idx];
    }
  }
  if (emptyIndexes.count > 0) {
    removeIndexesInReverse(_ranges, emptyIndexes);
  }
}

@end
