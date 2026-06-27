package com.swmansion.enriched.markdown.input.model

/**
 * Paragraph-level block kinds supported by the editor. Unlike inline styles
 * (bold, italic) which apply to character ranges, block styles apply to whole
 * lines and are mutually exclusive per line.
 */
enum class BlockType {
  PARAGRAPH,
  HEADING_1,
  HEADING_2,
  HEADING_3,
  ;

  /** Heading level (1-3) for a heading block, or 0 for non-headings. */
  val headingLevel: Int
    get() =
      when (this) {
        HEADING_1 -> 1
        HEADING_2 -> 2
        HEADING_3 -> 3
        else -> 0
      }

  companion object {
    fun forHeadingLevel(level: Int): BlockType =
      when (level) {
        1 -> HEADING_1
        2 -> HEADING_2
        3 -> HEADING_3
        else -> PARAGRAPH
      }
  }
}

/** A line range tagged with its block type, used to hand block structure to the serializer. */
data class BlockRange(
  val type: BlockType,
  val start: Int,
  val end: Int,
)
