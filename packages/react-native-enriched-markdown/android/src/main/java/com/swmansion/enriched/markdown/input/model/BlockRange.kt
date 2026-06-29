package com.swmansion.enriched.markdown.input.model

/**
 * A block-level element occupying a paragraph/line range. Mirrors [FormattingRange]
 * but for block scope: the range always covers whole lines.
 *
 * @property type the block kind (PARAGRAPH is the implicit default).
 * @property start inclusive start offset, in plain-text characters.
 * @property end exclusive end offset, in plain-text characters.
 * @property level generic integer payload, 0 by default. Headings use it for the
 *   H-level (1-6); list items will use it for nesting depth.
 */
data class BlockRange(
  val type: BlockType,
  var start: Int,
  var end: Int,
  var level: Int = 0,
) {
  val length: Int get() = end - start
}
