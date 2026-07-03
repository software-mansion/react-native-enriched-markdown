package com.swmansion.enriched.markdown.input.model

/**
 * A block-level element occupying a paragraph/line range. Mirrors [FormattingRange]
 * but for block scope: the range always covers whole lines.
 *
 * Deliberately NOT a data class: [start]/[end] mutate as edits shift ranges, so
 * value-based equals/hashCode would silently break set/map lookups. Identity
 * semantics are the safe default for a mutable model.
 *
 * @property type the block kind (PARAGRAPH is the implicit default).
 * @property start inclusive start offset, in plain-text characters.
 * @property end exclusive end offset, in plain-text characters.
 * @property level generic integer payload, 0 by default. Headings use it for the
 *   H-level (1-6); list items will use it for nesting depth.
 */
class BlockRange(
  val type: BlockType,
  override var start: Int,
  override var end: Int,
  var level: Int = 0,
) : MutableRangeBounds {
  val length: Int get() = end - start
}
