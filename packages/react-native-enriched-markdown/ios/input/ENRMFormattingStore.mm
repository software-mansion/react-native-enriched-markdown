#import "ENRMFormattingStore.h"

static NSUInteger sortedInsertionIndex(NSArray<ENRMFormattingRange *> *ranges, NSUInteger location)
{
  NSUInteger index = 0;
  for (ENRMFormattingRange *existing in ranges) {
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

typedef NS_ENUM(NSInteger, EditOverlap) {
  EditOverlapBeforeEdit,
  EditOverlapAfterEdit,
  EditOverlapFullyDeleted,
  EditOverlapDeletedInside,
  EditOverlapClippedEnd,
  EditOverlapClippedStart,
};

static EditOverlap classifyOverlap(NSUInteger rangeStart, NSUInteger rangeEnd, NSUInteger editLocation,
                                   NSUInteger deleteEnd)
{
  if (rangeEnd <= editLocation)
    return EditOverlapBeforeEdit;
  if (rangeStart >= deleteEnd)
    return EditOverlapAfterEdit;
  if (rangeStart >= editLocation && rangeEnd <= deleteEnd)
    return EditOverlapFullyDeleted;
  if (rangeStart < editLocation && rangeEnd > deleteEnd)
    return EditOverlapDeletedInside;
  if (rangeStart < editLocation && rangeEnd <= deleteEnd)
    return EditOverlapClippedEnd;
  return EditOverlapClippedStart;
}

@implementation ENRMFormattingStore {
  NSMutableArray<ENRMFormattingRange *> *_ranges;
}

- (instancetype)init
{
  if (self = [super init]) {
    _ranges = [NSMutableArray array];
  }
  return self;
}

- (NSArray<ENRMFormattingRange *> *)allRanges
{
  return [_ranges copy];
}

- (NSArray<ENRMFormattingRange *> *)rangesOfType:(ENRMInputStyleType)type
{
  NSMutableArray<ENRMFormattingRange *> *result = [NSMutableArray array];
  for (ENRMFormattingRange *formattingRange in _ranges) {
    if (formattingRange.type == type) {
      [result addObject:formattingRange];
    }
  }
  return result;
}

- (void)setRanges:(NSArray<ENRMFormattingRange *> *)ranges
{
  _ranges =
      [[ranges sortedArrayUsingComparator:^NSComparisonResult(ENRMFormattingRange *first, ENRMFormattingRange *second) {
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

- (nullable ENRMFormattingRange *)rangeOfType:(ENRMInputStyleType)type containingPosition:(NSUInteger)position
{
  for (ENRMFormattingRange *formattingRange in _ranges) {
    if (formattingRange.type != type)
      continue;
    if (position >= formattingRange.range.location && position < NSMaxRange(formattingRange.range)) {
      return formattingRange;
    }
  }
  return nil;
}

- (BOOL)isStyleActive:(ENRMInputStyleType)type atPosition:(NSUInteger)position
{
  return [self rangeOfType:type containingPosition:position] != nil;
}

- (BOOL)isStyleActive:(ENRMInputStyleType)type inRange:(NSRange)range
{
  for (ENRMFormattingRange *formattingRange in _ranges) {
    if (formattingRange.type == type && NSIntersectionRange(formattingRange.range, range).length > 0) {
      return YES;
    }
  }
  return NO;
}

- (void)addRange:(ENRMFormattingRange *)newRange
{
  NSMutableIndexSet *mergeIndexes = [NSMutableIndexSet indexSet];
  NSUInteger mergedStart = newRange.range.location;
  NSUInteger mergedEnd = NSMaxRange(newRange.range);

  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMFormattingRange *existing = _ranges[idx];
    if (existing.type != newRange.type)
      continue;

    NSUInteger existingEnd = NSMaxRange(existing.range);
    if (existing.range.location <= mergedEnd && existingEnd >= mergedStart) {
      mergedStart = MIN(mergedStart, existing.range.location);
      mergedEnd = MAX(mergedEnd, existingEnd);
      [mergeIndexes addIndex:idx];
    }
  }

  removeIndexesInReverse(_ranges, mergeIndexes);

  ENRMFormattingRange *merged = [ENRMFormattingRange rangeWithType:newRange.type
                                                             range:NSMakeRange(mergedStart, mergedEnd - mergedStart)
                                                               url:newRange.url];

  NSUInteger insertAt = sortedInsertionIndex(_ranges, merged.range.location);
  [_ranges insertObject:merged atIndex:insertAt];
}

- (void)removeType:(ENRMInputStyleType)type inRange:(NSRange)removeRange
{
  NSMutableArray<ENRMFormattingRange *> *remainders = [NSMutableArray array];
  NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];

  NSUInteger removeStart = removeRange.location;
  NSUInteger removeEnd = NSMaxRange(removeRange);

  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMFormattingRange *existing = _ranges[idx];
    if (existing.type != type)
      continue;

    NSUInteger existingStart = existing.range.location;
    NSUInteger existingEnd = NSMaxRange(existing.range);

    if (existingEnd <= removeStart || existingStart >= removeEnd) {
      continue;
    }

    [indexesToRemove addIndex:idx];

    if (existingStart < removeStart) {
      [remainders addObject:[ENRMFormattingRange rangeWithType:type
                                                         range:NSMakeRange(existingStart, removeStart - existingStart)
                                                           url:existing.url]];
    }
    if (existingEnd > removeEnd) {
      [remainders addObject:[ENRMFormattingRange rangeWithType:type
                                                         range:NSMakeRange(removeEnd, existingEnd - removeEnd)
                                                           url:existing.url]];
    }
  }

  removeIndexesInReverse(_ranges, indexesToRemove);

  // Remainders are fragments of a just-removed range and cannot overlap others.
  for (ENRMFormattingRange *remainder in remainders) {
    NSUInteger insertAt = sortedInsertionIndex(_ranges, remainder.range.location);
    [_ranges insertObject:remainder atIndex:insertAt];
  }
}

- (void)removeRange:(ENRMFormattingRange *)range
{
  [_ranges removeObject:range];
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
    ENRMFormattingRange *formattingRange = _ranges[idx];
    NSUInteger rangeStart = formattingRange.range.location;
    NSUInteger rangeEnd = NSMaxRange(formattingRange.range);

    if (deletedLength > 0) {
      EditOverlap overlap = classifyOverlap(rangeStart, rangeEnd, editLocation, deleteEnd);

      switch (overlap) {
        case EditOverlapBeforeEdit:
          break;

        case EditOverlapAfterEdit:
          formattingRange.range =
              NSMakeRange(rangeStart - deletedLength + insertedLength, formattingRange.range.length);
          break;

        case EditOverlapFullyDeleted:
          [indexesToRemove addIndex:idx];
          break;

        case EditOverlapDeletedInside: {
          NSUInteger newLength = formattingRange.range.length - deletedLength + insertedLength;
          formattingRange.range = NSMakeRange(rangeStart, newLength);
          break;
        }

        case EditOverlapClippedEnd: {
          NSUInteger newEnd = editLocation + insertedLength;
          NSUInteger newLength = newEnd > rangeStart ? newEnd - rangeStart : 0;
          formattingRange.range = NSMakeRange(rangeStart, newLength);
          if (newLength == 0) {
            [indexesToRemove addIndex:idx];
          }
          break;
        }

        case EditOverlapClippedStart: {
          NSUInteger charsClipped = deleteEnd - rangeStart;
          NSUInteger newStart = editLocation + insertedLength;
          NSUInteger newLength = formattingRange.range.length - charsClipped;
          formattingRange.range = NSMakeRange(newStart, newLength);
          if (newLength == 0) {
            [indexesToRemove addIndex:idx];
          }
          break;
        }
      }
    } else {
      if (rangeStart >= editLocation) {
        // Insertion at or before the range start: shift right.
        // _pendingStyles handles whether the inserted text inherits the style.
        formattingRange.range = NSMakeRange(rangeStart + insertedLength, formattingRange.range.length);
      } else if (editLocation < rangeEnd) {
        formattingRange.range = NSMakeRange(rangeStart, formattingRange.range.length + insertedLength);
      }
      // Typing at rangeEnd does not expand — pending styles control
      // whether new text at the boundary inherits the style.
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
