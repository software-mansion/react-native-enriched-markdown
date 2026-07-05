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
    // An anchored block (heading, list item) on an empty line is kept as a zero-length
    // anchor (see adjustForEdit); other blocks need real content.
    if (end < start || (end == start && type !in BlockType.ANCHORED)) return

    val block = BlockRange(type, start, end, level)
    ranges.add(sortedInsertionIndex(ranges, start), block)
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
   * Shifts/clips block ranges to follow a text edit (see [RangeEditAdjustment]),
   * with anchored-block (heading / list item) persistence layered on top: a block
   * deleted exactly to its end collapses to a zero-length anchor at the edit
   * location (its line survives), and existing anchors shift/keep/drop with their
   * line. The view's prune/normalize pass reconciles anchors against the final text.
   */
  fun adjustForEdit(
    editLocation: Int,
    deletedLength: Int,
    insertedLength: Int,
  ) {
    if (deletedLength == 0 && insertedLength == 0) return

    val deleteEnd = editLocation + deletedLength
    val delta = insertedLength - deletedLength

    val anchors = ranges.filter { it.length == 0 && it.type in BlockType.ANCHORED }
    ranges.removeAll { it.length == 0 }

    // At most one range can end exactly at deleteEnd, so this restores at most
    // one collapsed block.
    val collapsed =
      ranges.firstOrNull {
        it.type in BlockType.ANCHORED && it.start >= editLocation && it.end == deleteEnd
      }

    RangeEditAdjustment.adjustForEdit(ranges, editLocation, deletedLength, insertedLength)

    for (anchor in anchors) {
      when {
        anchor.start <= editLocation -> { /* keeps its position */ }

        anchor.start >= deleteEnd -> {
          anchor.start += delta
          anchor.end = anchor.start
        }

        else -> {
          continue // the anchor's line was deleted
        }
      }
      ranges.add(sortedInsertionIndex(ranges, anchor.start), anchor)
    }

    if (collapsed != null) {
      ranges.add(
        sortedInsertionIndex(ranges, editLocation),
        BlockRange(collapsed.type, editLocation, editLocation, collapsed.level),
      )
    }
  }

  /**
   * Snaps every stored range to the line bounds of its start position.
   * Absorbs edge-typed chars, clips split ranges to first line, drops
   * duplicates. On an empty line an anchored block (heading, list item)
   * persists as a zero-length anchor; any other collapsed range is dropped.
   * List depths are clamped so an item nests at most one level under the
   * previous adjacent item (CommonMark cannot represent orphan nesting).
   * Call after [adjustForEdit] once [text] is final. Idempotent.
   */
  fun normalizeToLineBounds(text: CharSequence) {
    if (ranges.isEmpty()) return

    var previousEnd = -1
    val iterator = ranges.listIterator()
    while (iterator.hasNext()) {
      val range = iterator.next()
      val (lineStart, lineEnd) = paragraphBounds(range.start, range.start, text)
      val isEmptyLine = lineEnd == lineStart
      if ((isEmptyLine && range.type !in BlockType.ANCHORED) || lineStart <= previousEnd) {
        iterator.remove()
        continue
      }
      range.start = lineStart
      range.end = lineEnd
      previousEnd = lineEnd
    }

    clampListDepths()
  }

  private fun clampListDepths() {
    var prevListEnd = -2
    var prevListDepth = -1
    for (range in ranges) {
      if (range.type != BlockType.UNORDERED_LIST_ITEM) continue
      val maxDepth = if (range.start == prevListEnd + 1) prevListDepth + 1 else 0
      if (range.level > maxDepth) range.level = maxDepth
      prevListEnd = range.end
      prevListDepth = range.level
    }
  }

  /**
   * Drops any stored block overlapping `[start, end)`. Blocks never partially
   * overlap, so a touched block is removed wholesale; a zero-length anchor is
   * dropped when it sits within the bounds (so toggle-off clears an empty line).
   */
  private fun removeBlocksOverlapping(
    start: Int,
    end: Int,
  ) {
    ranges.removeAll { (it.end > start && it.start < end) || (it.length == 0 && it.start in start..end) }
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
}
