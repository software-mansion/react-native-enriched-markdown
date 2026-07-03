package com.swmansion.enriched.markdown.input.formatting

import android.util.Log
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType

object MarkdownSerializer {
  private const val TAG = "MarkdownSerializer"

  /**
   * Block-aware serialization: serializes inline styles exactly as the inline-only
   * overload, then prepends each line's block prefix. [blockPrefixProvider] is
   * asked, per block range, for the markdown line marker (e.g. `"# "`, `"- "`);
   * returning `""` leaves the line unprefixed. With empty [blockRanges] the output
   * is identical to the inline-only overload.
   */
  fun serialize(
    text: String,
    ranges: List<FormattingRange>,
    blockRanges: List<BlockRange>,
    blockPrefixProvider: (BlockRange) -> String,
  ): String {
    val inlineMarkdown = serialize(text, ranges)
    if (blockRanges.isEmpty()) return inlineMarkdown

    // Block prefixes attach per line. Inline serialization only inserts inline
    // delimiters (never newlines), so the serialized output has the same line
    // count as the plain text — we map a block's plain-text range to line indices
    // and prefix the corresponding serialized lines.
    val plainLines = text.split("\n")
    val markdownLines = inlineMarkdown.split("\n").toMutableList()

    // Inline delimiters never cross a newline, so the line partition is preserved.
    // If this ever breaks, prefixes would land on the wrong lines. Contract on
    // both platforms: log and fall back to inline-only output — a library must
    // not crash the host app over lost block prefixes.
    if (plainLines.size != markdownLines.size) {
      Log.e(TAG, "Block serialization line-count invariant violated: plain=${plainLines.size} markdown=${markdownLines.size}")
      return inlineMarkdown
    }

    // Plain-text character offset at the start of each line.
    val lineStartOffsets = IntArray(plainLines.size)
    var runningOffset = 0
    for (i in plainLines.indices) {
      lineStartOffsets[i] = runningOffset
      runningOffset += plainLines[i].length + 1 // +1 for the '\n' separator
    }

    for (blockRange in blockRanges) {
      val prefix = blockPrefixProvider(blockRange)
      if (prefix.isEmpty()) continue

      for (lineIndex in plainLines.indices) {
        val lineStart = lineStartOffsets[lineIndex]
        val lineEnd = lineStart + plainLines[lineIndex].length
        // A block claims a line if their ranges intersect (block ranges are
        // line-scoped, so this covers single- and multi-line blocks).
        if (lineEnd >= blockRange.start && lineStart < blockRange.end) {
          markdownLines[lineIndex] = prefix + markdownLines[lineIndex]
        }
      }
    }

    return markdownLines.joinToString("\n")
  }

  fun serialize(
    text: String,
    ranges: List<FormattingRange>,
  ): String {
    if (ranges.isEmpty()) return text

    val events = ArrayList<BoundaryEvent>(ranges.size * 2)
    for (range in ranges) {
      var start = range.start.coerceIn(0, text.length)
      var end = range.end.coerceIn(0, text.length)

      if (start >= end) continue

      // Trim leading/trailing whitespace so delimiters hug non-whitespace content
      while (start < end && text[start].isWhitespace()) start++
      while (end > start && text[end - 1].isWhitespace()) end--

      if (start >= end) continue

      events.add(BoundaryEvent(start, true, range.type, range.url))
      events.add(BoundaryEvent(end, false, range.type, range.url))
    }

    events.sortWith(BOUNDARY_COMPARATOR)

    val markdown = StringBuilder(text.length + events.size * 4)
    var lastPosition = 0

    for (event in events) {
      val position = event.position.coerceAtMost(text.length)

      if (position > lastPosition) {
        markdown.append(text, lastPosition, position)
        lastPosition = position
      }

      if (event.isOpening) {
        markdown.append(openingDelimiter(event.type))
      } else {
        markdown.append(closingDelimiter(event.type, event.url))
      }
    }

    if (lastPosition < text.length) {
      markdown.append(text, lastPosition, text.length)
    }

    return markdown.toString()
  }

  private fun openingDelimiter(type: StyleType): String =
    when (type) {
      StyleType.BOLD -> "**"
      StyleType.ITALIC -> "*"
      StyleType.UNDERLINE -> "_"
      StyleType.STRIKETHROUGH -> "~~"
      StyleType.LINK -> "["
      StyleType.SPOILER -> "||"
    }

  private fun closingDelimiter(
    type: StyleType,
    url: String?,
  ): String =
    when (type) {
      StyleType.BOLD -> "**"
      StyleType.ITALIC -> "*"
      StyleType.UNDERLINE -> "_"
      StyleType.STRIKETHROUGH -> "~~"
      StyleType.LINK -> "](${url ?: ""})"
      StyleType.SPOILER -> "||"
    }

  // Lower value = outermost wrapper. Font styles wrap around structural styles (link).
  private fun nestingPriority(type: StyleType): Int =
    when (type) {
      StyleType.ITALIC -> 0
      StyleType.BOLD -> 1
      StyleType.UNDERLINE -> 2
      StyleType.STRIKETHROUGH -> 3
      StyleType.SPOILER -> 4
      StyleType.LINK -> 5
    }

  private data class BoundaryEvent(
    val position: Int,
    val isOpening: Boolean,
    val type: StyleType,
    val url: String?,
  )

  private val BOUNDARY_COMPARATOR =
    Comparator<BoundaryEvent> { a, b ->
      if (a.position != b.position) {
        return@Comparator a.position - b.position
      }
      // Closing events before opening events at the same position
      if (a.isOpening != b.isOpening) {
        return@Comparator if (a.isOpening) 1 else -1
      }
      // Among openings: outer first (lower priority emitted first)
      // Among closings: inner first (higher priority emitted first) — LIFO order
      if (a.isOpening) {
        nestingPriority(a.type) - nestingPriority(b.type)
      } else {
        nestingPriority(b.type) - nestingPriority(a.type)
      }
    }
}
