package com.swmansion.enriched.markdown.input.styles

import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.InputFormatterStyle
import com.swmansion.enriched.markdown.input.spans.InputHeadingSpan

/**
 * Block handler for ATX headings (H1-H6). A single instance serves all six levels:
 * it reads the H-level from each [BlockRange.level], so it is registered in the
 * [com.swmansion.enriched.markdown.input.formatting.InputFormatter] under every
 * `HEADING_n` key. The level — not [blockType] — drives styling and serialization,
 * so [blockType] is only a nominal interface value and never consulted by the
 * formatter (it dispatches on `range.type`).
 */
class HeadingBlockHandler : BlockHandler {
  override val blockType: BlockType = BlockType.HEADING_1

  override fun createSpans(
    blockRange: BlockRange,
    style: InputFormatterStyle,
  ): List<Any> = listOf(InputHeadingSpan(blockRange.level, style))

  override fun spanClasses(): List<Class<*>> = listOf(InputHeadingSpan::class.java)

  override fun markdownLinePrefix(blockRange: BlockRange): String = "#".repeat(blockRange.level.coerceIn(1, 6)) + " "
}
