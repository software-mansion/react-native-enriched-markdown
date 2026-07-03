#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
  NSRange range;
  BOOL shouldRemove;
} ENRMAdjustedRange;

/// Shared shift/clip logic applied to a stored range after a text edit that
/// replaced `deletedLength` characters at `editLocation` with `insertedLength`
/// characters. Both ENRMFormattingStore and ENRMBlockStore delegate here so the
/// overlap classification lives in exactly one place. `shouldRemove` is set
/// when the range was deleted outright or clipped to zero length.
///
/// Insert-only edits at exactly the range start or end do NOT grow the range —
/// the typed characters stay outside it. Whether boundary text joins the range
/// is decided elsewhere: pending styles for inline ranges, line
/// re-normalization for block ranges.
ENRMAdjustedRange ENRMAdjustRangeForEdit(NSRange range, NSUInteger editLocation, NSUInteger deletedLength,
                                         NSUInteger insertedLength);

NS_ASSUME_NONNULL_END
