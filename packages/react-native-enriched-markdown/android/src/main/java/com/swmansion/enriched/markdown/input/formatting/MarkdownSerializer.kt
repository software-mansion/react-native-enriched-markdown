package com.swmansion.enriched.markdown.input.formatting

import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType

object MarkdownSerializer {
  /**
   * Serializes inline marks and then prefixes each line with its block marker
   * (`# `/`## `/`### ` for headings). Block markers are line-based, so this runs
   * after inline serialization, which preserves the text's line structure.
   */
  fun serialize(
    text: String,
    ranges: List<FormattingRange>,
    blockRanges: List<BlockRange>,
  ): String {
    val inline = serialize(text, ranges)
    if (blockRanges.isEmpty()) return inline

    val plainLines = text.split("\n")
    val markdownLines = inline.split("\n").toMutableList()
    // Inline serialization never adds or removes newlines, so line counts align;
    // bail out safely if that invariant is ever broken.
    if (plainLines.size != markdownLines.size) return inline

    var lineStart = 0
    for (i in plainLines.indices) {
      val lineLength = plainLines[i].length
      val lineEnd = lineStart + lineLength
      val level =
        blockRanges
          .firstOrNull { br ->
            br.type.headingLevel > 0 &&
              (
                maxOf(lineStart, br.start) < minOf(lineEnd, br.end) ||
                  (lineLength == 0 && lineStart >= br.start && lineStart < br.end)
              )
          }?.type
          ?.headingLevel ?: 0
      if (level > 0) {
        markdownLines[i] = "#".repeat(level) + " " + markdownLines[i]
      }
      lineStart = lineEnd + 1
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
