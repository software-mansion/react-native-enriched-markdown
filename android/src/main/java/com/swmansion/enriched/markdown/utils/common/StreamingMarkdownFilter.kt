package com.swmansion.enriched.markdown.utils.common

enum class TableStreamingMode {
  HIDDEN,
  PROGRESSIVE,
}

/**
 * Pre-parse filter that hides incomplete trailing tables and block math
 * during streaming. A table is considered complete only after a blank
 * separator line follows it; a block math (`$$`) is complete only when
 * a closing `$$` exists.
 */
object StreamingMarkdownFilter {
  fun renderableMarkdownForStreaming(
    markdown: String,
    tableMode: TableStreamingMode = TableStreamingMode.PROGRESSIVE,
  ): String {
    val lines = markdown.split("\n")
    val afterMath = removePendingStreamingMathBlock(markdown, lines)
    val linesForTable = if (afterMath.length == markdown.length) lines else afterMath.split("\n")
    return removePendingStreamingTableBlock(afterMath, linesForTable, tableMode)
  }

  private fun removePendingStreamingMathBlock(
    markdown: String,
    lines: List<String>,
  ): String {
    var lastUnclosedDelimiterIndex = -1

    for (i in lines.indices) {
      if (lineIsBlockMathDelimiter(lines[i])) {
        lastUnclosedDelimiterIndex = if (lastUnclosedDelimiterIndex == -1) i else -1
      }
    }

    if (lastUnclosedDelimiterIndex == -1) return markdown

    val offsets = buildLineOffsets(lines)
    return markdown.substring(0, offsets[lastUnclosedDelimiterIndex])
  }

  private fun removePendingStreamingTableBlock(
    markdown: String,
    lines: List<String>,
    tableMode: TableStreamingMode,
  ): String {
    var lastNonBlankLineIndex = -1

    for (i in lines.indices.reversed()) {
      if (!lineIsBlank(lines[i])) {
        lastNonBlankLineIndex = i
        break
      }
    }

    if (lastNonBlankLineIndex == -1) return markdown

    if (lastNonBlankLineIndex + 1 < lines.size - 1) return markdown

    var blockStartIndex = lastNonBlankLineIndex
    while (blockStartIndex > 0 && !lineIsBlank(lines[blockStartIndex - 1])) {
      blockStartIndex--
    }

    var blockLooksLikeTable = false
    for (i in blockStartIndex..lastNonBlankLineIndex) {
      if (!lineLooksLikeTableRow(lines[i])) return markdown
      blockLooksLikeTable = true
    }

    if (!blockLooksLikeTable) return markdown

    val offsets = buildLineOffsets(lines)

    if (tableMode == TableStreamingMode.PROGRESSIVE) {
      val tableLineCount = lastNonBlankLineIndex - blockStartIndex + 1

      if (tableLineCount < 2 || !lineLooksLikeTableSeparator(lines[blockStartIndex + 1])) {
        return markdown.substring(0, offsets[blockStartIndex])
      }

      if (tableLineCount > 2) {
        val lastRow = lines[lastNonBlankLineIndex]
        val lastRowTrimmed = lastRow.trim()
        val headerRow = lines[blockStartIndex]
        if (!lastRowTrimmed.endsWith("|") || pipeCount(lastRow) < pipeCount(headerRow)) {
          return markdown.substring(0, offsets[lastNonBlankLineIndex])
        }
      }

      return markdown
    }

    return markdown.substring(0, offsets[blockStartIndex])
  }

  private fun lineIsBlank(line: String): Boolean = line.isBlank()

  private fun lineIsBlockMathDelimiter(line: String): Boolean = line.trim() == "$$"

  private fun lineLooksLikeTableRow(line: String): Boolean {
    val trimmed = line.trim()
    return trimmed.startsWith("|")
  }

  private fun lineLooksLikeTableSeparator(line: String): Boolean {
    val trimmed = line.trim()
    if (trimmed.isEmpty()) return false
    if (trimmed[0] != '|') return false
    var hasTripleDash = false
    var dashRun = 0
    for (ch in trimmed) {
      if (ch == '-') {
        dashRun++
        if (dashRun >= 3) hasTripleDash = true
      } else {
        dashRun = 0
        if (ch != '|' && ch != ':' && ch != ' ') return false
      }
    }
    return hasTripleDash
  }

  private fun pipeCount(line: String): Int {
    var count = 0
    for (ch in line) {
      if (ch == '|') count++
    }
    return count
  }

  private fun buildLineOffsets(lines: List<String>): IntArray {
    val offsets = IntArray(lines.size)
    var currentOffset = 0
    for (i in lines.indices) {
      offsets[i] = currentOffset
      currentOffset += lines[i].length + 1
    }
    return offsets
  }
}
