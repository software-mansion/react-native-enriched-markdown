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

  /** Shifts/clips block ranges to follow a text edit. See [RangeEditAdjustment]. */
  fun adjustForEdit(
    editLocation: Int,
    deletedLength: Int,
    insertedLength: Int,
  ) {
    RangeEditAdjustment.adjustForEdit(ranges, editLocation, deletedLength, insertedLength)
  }

  /**
   * Re-normalizes every stored range back to the whole-line bounds of the line
   * containing its start. Call after [adjustForEdit] once [text] is final:
   * [adjustForEdit] deliberately leaves characters inserted at a range's start
   * or end outside the range (matching [FormattingStore]'s convention), and a
   * newline typed inside a range leaves it spanning two lines. Re-snapping to
   * line bounds re-absorbs edge-typed characters, clips a split range to its
   * first line (the text after the caret becomes a plain paragraph), and drops
   * blocks that a line-join landed on an earlier block's line (first wins).
   * Idempotent: ranges already line-scoped are untouched.
   */
  fun normalizeToLineBounds(text: CharSequence) {
    if (ranges.isEmpty()) return

    var previousEnd = -1
    val iterator = ranges.listIterator()
    while (iterator.hasNext()) {
      val range = iterator.next()
      val (lineStart, lineEnd) = paragraphBounds(range.start, range.start, text)
      if (lineEnd <= lineStart || lineStart <= previousEnd) {
        iterator.remove()
        continue
      }
      range.start = lineStart
      range.end = lineEnd
      previousEnd = lineEnd
    }
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
}
