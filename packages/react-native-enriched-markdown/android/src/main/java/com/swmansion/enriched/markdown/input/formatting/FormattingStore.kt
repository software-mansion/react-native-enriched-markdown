package com.swmansion.enriched.markdown.input.formatting

import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType
import java.util.Collections

class FormattingStore {
  private val ranges = mutableListOf<FormattingRange>()

  val allRanges: List<FormattingRange> get() = Collections.unmodifiableList(ranges)

  fun setRanges(newRanges: List<FormattingRange>) {
    ranges.clear()
    ranges.addAll(newRanges.sortedBy { it.start })
  }

  fun clearAll() {
    ranges.clear()
  }

  fun rangeOfType(
    type: StyleType,
    containingPosition: Int,
  ): FormattingRange? = ranges.firstOrNull { it.type == type && containingPosition >= it.start && containingPosition < it.end }

  fun isStyleActive(
    type: StyleType,
    position: Int,
  ): Boolean = rangeOfType(type, position) != null

  fun isStyleActiveInRange(
    type: StyleType,
    start: Int,
    end: Int,
  ): Boolean = ranges.any { it.type == type && it.start < end && it.end > start }

  fun addRange(newRange: FormattingRange) {
    var mergedStart = newRange.start
    var mergedEnd = newRange.end
    val mergeIndexes = mutableListOf<Int>()

    for ((idx, existing) in ranges.withIndex()) {
      if (existing.type != newRange.type) continue
      if (existing.start <= mergedEnd && existing.end >= mergedStart) {
        mergedStart = minOf(mergedStart, existing.start)
        mergedEnd = maxOf(mergedEnd, existing.end)
        mergeIndexes.add(idx)
      }
    }

    for (idx in mergeIndexes.reversed()) {
      ranges.removeAt(idx)
    }

    val merged = FormattingRange(newRange.type, mergedStart, mergedEnd, newRange.url)
    val insertAt = sortedInsertionIndex(mergedStart)
    ranges.add(insertAt, merged)
  }

  fun removeType(
    type: StyleType,
    start: Int,
    end: Int,
  ) {
    val remainders = mutableListOf<FormattingRange>()
    val indexesToRemove = mutableListOf<Int>()

    for ((idx, existing) in ranges.withIndex()) {
      if (existing.type != type) continue
      if (existing.end <= start || existing.start >= end) continue

      indexesToRemove.add(idx)

      if (existing.start < start) {
        remainders.add(FormattingRange(type, existing.start, start, existing.url))
      }
      if (existing.end > end) {
        remainders.add(FormattingRange(type, end, existing.end, existing.url))
      }
    }

    for (idx in indexesToRemove.reversed()) {
      ranges.removeAt(idx)
    }

    // Remainders are fragments of a just-removed range and cannot overlap others.
    for (remainder in remainders) {
      val insertAt = sortedInsertionIndex(remainder.start)
      ranges.add(insertAt, remainder)
    }
  }

  fun removeRange(range: FormattingRange) {
    ranges.remove(range)
  }

  fun adjustForEdit(
    editLocation: Int,
    deletedLength: Int,
    insertedLength: Int,
  ) {
    if (deletedLength == 0 && insertedLength == 0) return

    val deleteEnd = editLocation + deletedLength
    val indexesToRemove = mutableListOf<Int>()

    for ((idx, range) in ranges.withIndex()) {
      if (deletedLength > 0) {
        when (classifyOverlap(range.start, range.end, editLocation, deleteEnd)) {
          EditOverlap.BEFORE_EDIT -> { /* no change */ }

          EditOverlap.AFTER_EDIT -> {
            range.start = range.start - deletedLength + insertedLength
            range.end = range.end - deletedLength + insertedLength
          }

          EditOverlap.FULLY_DELETED -> {
            indexesToRemove.add(idx)
          }

          EditOverlap.DELETED_INSIDE -> {
            range.end = range.end - deletedLength + insertedLength
          }

          EditOverlap.CLIPPED_END -> {
            val newEnd = editLocation + insertedLength
            val newLength = if (newEnd > range.start) newEnd - range.start else 0
            range.end = range.start + newLength
            if (newLength == 0) indexesToRemove.add(idx)
          }

          EditOverlap.CLIPPED_START -> {
            val charsClipped = deleteEnd - range.start
            val newStart = editLocation + insertedLength
            val oldLength = range.length
            range.start = newStart
            range.end = newStart + oldLength - charsClipped
            if (range.length == 0) indexesToRemove.add(idx)
          }
        }
      } else {
        when {
          range.start >= editLocation -> {
            range.start += insertedLength
            range.end += insertedLength
          }

          editLocation > range.start && editLocation < range.end -> {
            range.end += insertedLength
          }
        }
      }
    }

    for (idx in indexesToRemove.reversed()) {
      ranges.removeAt(idx)
    }

    ranges.removeAll { it.length == 0 }
  }

  private fun sortedInsertionIndex(location: Int): Int {
    var index = 0
    for (existing in ranges) {
      if (existing.start > location) break
      index++
    }
    return index
  }

  private enum class EditOverlap {
    BEFORE_EDIT,
    AFTER_EDIT,
    FULLY_DELETED,
    DELETED_INSIDE,
    CLIPPED_END,
    CLIPPED_START,
  }

  private fun classifyOverlap(
    rangeStart: Int,
    rangeEnd: Int,
    editLocation: Int,
    deleteEnd: Int,
  ): EditOverlap {
    if (rangeEnd <= editLocation) return EditOverlap.BEFORE_EDIT
    if (rangeStart >= deleteEnd) return EditOverlap.AFTER_EDIT
    if (rangeStart >= editLocation && rangeEnd <= deleteEnd) return EditOverlap.FULLY_DELETED
    if (rangeStart < editLocation && rangeEnd > deleteEnd) return EditOverlap.DELETED_INSIDE
    return if (rangeStart < editLocation) EditOverlap.CLIPPED_END else EditOverlap.CLIPPED_START
  }
}
