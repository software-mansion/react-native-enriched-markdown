package com.swmansion.enriched.markdown.input.model

/**
 * Block-level (paragraph-scoped) element types. A block covers whole lines,
 * unlike inline styles ([StyleType]) which cover character ranges.
 *
 * PARAGRAPH is the default: every line is a paragraph until a block handler
 * claims it. Concrete block types (headings, list items, etc.) are appended
 * here as their handlers are added — each new case must have a matching
 * [com.swmansion.enriched.markdown.input.styles.BlockHandler] registered in
 * [com.swmansion.enriched.markdown.input.formatting.InputFormatter].
 */
enum class BlockType {
  PARAGRAPH,
}
