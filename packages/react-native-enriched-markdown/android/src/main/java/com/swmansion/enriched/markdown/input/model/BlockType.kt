package com.swmansion.enriched.markdown.input.model

/**
 * Paragraph-level block kinds supported by the editor. Unlike inline styles
 * (bold, italic) which apply to character ranges, block styles apply to whole
 * lines and are mutually exclusive per line.
 */
enum class BlockType {
  PARAGRAPH,
  UNORDERED_LIST_ITEM,
}

/** Maximum supported list nesting depth (0-based), so indentation stays sane. */
const val MAX_LIST_DEPTH = 5

/** A line range tagged with its block type and nesting depth, used to hand block structure to the serializer. */
data class BlockRange(
  val type: BlockType,
  val start: Int,
  val end: Int,
  val depth: Int = 0,
)
