#import "ENRMRangeEditAdjustment.h"

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

ENRMAdjustedRange ENRMAdjustRangeForEdit(NSRange range, NSUInteger editLocation, NSUInteger deletedLength,
                                         NSUInteger insertedLength)
{
  ENRMAdjustedRange result = {range, NO};
  NSUInteger rangeStart = range.location;
  NSUInteger rangeEnd = NSMaxRange(range);

  if (deletedLength > 0) {
    NSUInteger deleteEnd = editLocation + deletedLength;

    switch (classifyOverlap(rangeStart, rangeEnd, editLocation, deleteEnd)) {
      case EditOverlapBeforeEdit:
        break;

      case EditOverlapAfterEdit:
        result.range = NSMakeRange(rangeStart - deletedLength + insertedLength, range.length);
        break;

      case EditOverlapFullyDeleted:
        result.shouldRemove = YES;
        break;

      case EditOverlapDeletedInside:
        result.range = NSMakeRange(rangeStart, range.length - deletedLength + insertedLength);
        break;

      case EditOverlapClippedEnd: {
        NSUInteger newEnd = editLocation + insertedLength;
        NSUInteger newLength = newEnd > rangeStart ? newEnd - rangeStart : 0;
        result.range = NSMakeRange(rangeStart, newLength);
        result.shouldRemove = (newLength == 0);
        break;
      }

      case EditOverlapClippedStart: {
        NSUInteger charsClipped = deleteEnd - rangeStart;
        NSUInteger newStart = editLocation + insertedLength;
        NSUInteger newLength = range.length - charsClipped;
        result.range = NSMakeRange(newStart, newLength);
        result.shouldRemove = (newLength == 0);
        break;
      }
    }
  } else if (insertedLength > 0) {
    if (rangeStart >= editLocation) {
      result.range = NSMakeRange(rangeStart + insertedLength, range.length);
    } else if (editLocation < rangeEnd) {
      result.range = NSMakeRange(rangeStart, range.length + insertedLength);
    }
  }

  return result;
}
