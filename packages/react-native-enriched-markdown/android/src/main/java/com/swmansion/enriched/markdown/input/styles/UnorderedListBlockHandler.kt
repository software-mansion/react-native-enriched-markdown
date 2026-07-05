package com.swmansion.enriched.markdown.input.styles

import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.InputFormatterStyle
import com.swmansion.enriched.markdown.input.spans.InputBulletSpan
import com.swmansion.enriched.markdown.input.spans.InputListItemSpacingSpan

/**
 * Block handler for unordered (bullet) list items. One instance serves every
 * nesting depth — the 0-based depth rides in [BlockRange.level] and drives the
 * indent, marker glyph, and serialized indentation.
 */
class UnorderedListBlockHandler : BlockHandler {
  override val blockType: BlockType = BlockType.UNORDERED_LIST_ITEM

  override val continuesOnNewline: Boolean = true

  override fun createSpans(
    blockRange: BlockRange,
    style: InputFormatterStyle,
  ): List<Any> {
    val spans = mutableListOf<Any>(InputBulletSpan(blockRange.level, style.displayDensity))
    if (style.listItemSpacingPx > 0) {
      spans.add(InputListItemSpacingSpan(style.listItemSpacingPx))
    }
    return spans
  }

  override fun spanClasses(): List<Class<*>> = listOf(InputBulletSpan::class.java, InputListItemSpacingSpan::class.java)

  /** `"- "` for a top-level item, indented two spaces per nesting depth (mirrors iOS). */
  override fun markdownLinePrefix(blockRange: BlockRange): String = "  ".repeat(blockRange.level.coerceAtLeast(0)) + "- "
}
