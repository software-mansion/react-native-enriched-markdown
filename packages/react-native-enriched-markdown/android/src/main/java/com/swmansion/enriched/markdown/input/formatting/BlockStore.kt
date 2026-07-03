package com.swmansion.enriched.markdown.input.formatting

import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import java.util.Collections

/**
 * Stores the block-level (paragraph-scoped) ranges for the editor, mirroring
 * [FormattingStore]. Unlike inline ranges, block ranges never overlap: at most
 * one block covers any given paragraph, and ranges are kept normalized to
 * whole-line boundaries.
 */
class BlockStore {
  private val ranges = mutableListOf<BlockRange>()

  val allRanges: List<BlockRange> get() = Collections.unmodifiableList(ranges)

  /**
   * Incoming ranges are trusted to be non-overlapping and line-scoped — the
   * parser owns that invariant (md4c block structure never overlaps at the same
   * nesting level, and nested containers are not yet mapped). Revisit
   * enforcement here if a container block type (list, blockquote) is added.
   */
  fun setRanges(newRanges: List<BlockRange>) {
    ranges.clear()
    ranges.addAll(newRanges.sortedBy { it.start })
  }

  fun clearAll() {
    ranges.clear()
  }

  fun blockRangeContaining(position: Int): BlockRange? = ranges.firstOrNull { position >= it.start && position < it.end }

  /**
   * Sets/replaces the block on every paragraph the given range touches, expanding
   * to whole-line boundaries within [text]. Removes any block previously covering
   * those paragraphs.
   */
  fun setBlock(
    type: BlockType,
    level: Int,
    paragraphStart: Int,
    paragraphEnd: Int,
    text: CharSequence,
  ) {
    val (start, end) = paragraphBounds(paragraphStart, paragraphEnd, text)
    removeBlocksOverlapping(start, end)
    if (end <= start) return

    val block = BlockRange(type, start, end, level)
    ranges.add(sortedInsertionIndex(start), block)
  }

  /**
   * Clears any block on the paragraphs the given range touches (reverting them to
   * the implicit paragraph default).
   */
  fun removeBlock(
    paragraphStart: Int,
    paragraphEnd: Int,
    text: CharSequence,
  ) {
    val (start, end) = paragraphBounds(paragraphStart, paragraphEnd, text)
    removeBlocksOverlapping(start, end)
  }

  /**
   * Shifts/clips block ranges to follow a text edit, using the same overlap
   * classification shape as [FormattingStore.adjustForEdit].
   */
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
        // Insert-only. Insertion at exactly range.start shifts the block right
        // (typed characters stay outside it) — same convention as
        // [FormattingStore]. A concrete block handler re-normalizes its line
        // bounds on the edit pass, so a leading insert rejoins the block there.
        when {
          range.start >= editLocation -> {
            range.start += insertedLength
            range.end += insertedLength
          }

          editLocation < range.end -> {
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

  /**
   * Drops any stored block overlapping `[start, end)` so a replacement can be
   * inserted cleanly. Blocks are line-scoped and never partially overlap, so a
   * touched block is removed wholesale.
   */
  private fun removeBlocksOverlapping(
    start: Int,
    end: Int,
  ) {
    ranges.removeAll { it.end > start && it.start < end }
  }

  /** Expands a selection to cover whole lines (line-scoped block boundaries). */
  private fun paragraphBounds(
    rangeStart: Int,
    rangeEnd: Int,
    text: CharSequence,
  ): Pair<Int, Int> {
    if (text.isEmpty()) return 0 to 0

    val clampedStart = rangeStart.coerceIn(0, text.length)
    val clampedEnd = rangeEnd.coerceIn(clampedStart, text.length)

    var lineStart = clampedStart
    while (lineStart > 0 && text[lineStart - 1] != '\n') lineStart--

    var lineEnd = clampedEnd
    while (lineEnd < text.length && text[lineEnd] != '\n') lineEnd++

    return lineStart to lineEnd
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
