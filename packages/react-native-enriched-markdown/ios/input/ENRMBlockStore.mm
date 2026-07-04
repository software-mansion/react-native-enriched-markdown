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

    // A zero-length anchor occupies a point, so the half-open overlap test
    // never matches it; drop one whose anchor lies within the removal bounds.
    if (existing.range.length == 0) {
      if (existingStart >= removeStart && existingStart <= removeEnd) {
        [indexesToRemove addIndex:idx];
      }
      continue;
    }

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

  // Store content-only bounds (the parser's convention): trim the line
  // terminator that paragraphRangeForRange includes (handles \r\n as well).
  while (paragraphRange.length > 0) {
    unichar last = [text characterAtIndex:NSMaxRange(paragraphRange) - 1];
    if (last != '\n' && last != '\r') {
      break;
    }
    paragraphRange.length--;
  }

  // Only headings persist on an empty line (as a zero-length anchor); other
  // block types have nothing to anchor.
  if (paragraphRange.length == 0 && ENRMHeadingLevelForBlockType(type) == 0) {
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

  NSUInteger deleteEnd = editLocation + deletedLength;
  NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];

  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMBlockRange *blockRange = _ranges[idx];
    BOOL isHeading = ENRMHeadingLevelForBlockType(blockRange.type) > 0;

    // Zero-length heading anchors don't follow the shared adjustment: one at
    // the edit location stays put (normalize grows it over the typed text),
    // one past the edit shifts with it, one inside the deletion is dropped.
    if (blockRange.range.length == 0) {
      if (!isHeading) {
        [indexesToRemove addIndex:idx];
      } else if (blockRange.range.location >= deleteEnd && blockRange.range.location > editLocation) {
        blockRange.range = NSMakeRange(blockRange.range.location - deletedLength + insertedLength, 0);
      } else if (blockRange.range.location > editLocation) {
        [indexesToRemove addIndex:idx]; // anchor sat inside the deleted region
      }
      continue;
    }

    ENRMAdjustedRange adjusted = ENRMAdjustRangeForEdit(blockRange.range, editLocation, deletedLength, insertedLength);
    if (adjusted.shouldRemove) {
      // A heading deleted exactly to its end collapses to a zero-length anchor
      // (the line's newline survived, so the line stays a heading); a deletion
      // running past its end removed the line, so drop the heading with it.
      if (isHeading && NSMaxRange(blockRange.range) == deleteEnd && blockRange.range.location >= editLocation) {
        blockRange.range = NSMakeRange(editLocation, 0);
      } else {
        [indexesToRemove addIndex:idx];
      }
      continue;
    }
    blockRange.range = adjusted.range;
  }

  removeIndexesInReverse(_ranges, indexesToRemove);

  // Prune zero-length ranges, but keep zero-length headings: they anchor an
  // emptied-but-still-present heading line (see the collapse rule above).
  NSMutableIndexSet *emptyIndexes = [NSMutableIndexSet indexSet];
  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMBlockRange *range = _ranges[idx];
    if (range.range.length == 0 && ENRMHeadingLevelForBlockType(range.type) == 0) {
      [emptyIndexes addIndex:idx];
    }
  }
  if (emptyIndexes.count > 0) {
    removeIndexesInReverse(_ranges, emptyIndexes);
  }
}

- (void)normalizeToLineBoundsInText:(NSString *)text
{
  if (_ranges.count == 0) {
    return;
  }

  NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
  NSInteger previousEnd = -1;

  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMBlockRange *blockRange = _ranges[idx];
    NSRange lineRange = paragraphBoundsForRange(NSMakeRange(blockRange.range.location, 0), text);

    // Block content ranges never cover the line terminator; paragraphRangeForRange
    // includes it, so trim it (handles \r\n as well).
    while (lineRange.length > 0) {
      unichar last = [text characterAtIndex:NSMaxRange(lineRange) - 1];
      if (last != '\n' && last != '\r') {
        break;
      }
      lineRange.length--;
    }

    // Headings persist on an empty line as a zero-length anchor; other
    // collapsed ranges are dropped.
    BOOL isHeading = ENRMHeadingLevelForBlockType(blockRange.type) > 0;
    if ((lineRange.length == 0 && !isHeading) || (NSInteger)lineRange.location <= previousEnd) {
      [indexesToRemove addIndex:idx];
      continue;
    }

    blockRange.range = lineRange;
    previousEnd = (NSInteger)NSMaxRange(lineRange);
  }

  removeIndexesInReverse(_ranges, indexesToRemove);
}

@end
