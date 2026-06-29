package com.swmansion.enriched.markdown.input.styles

import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.InputFormatterStyle
import com.swmansion.enriched.markdown.parser.MarkdownASTNode

/**
 * A block handler owns one [BlockType] end-to-end: how it styles its paragraph,
 * how it serializes to a markdown line prefix, and which parser block node it
 * maps from. Mirrors [StyleHandler] for the inline pipeline.
 *
 * Block spans are paragraph-scoped and applied over the block's whole line range
 * by [com.swmansion.enriched.markdown.input.formatting.InputFormatter]. Unlike
 * inline [StyleHandler.createSpans] (which returns `CharacterStyle`), a block
 * handler returns `List<Any>` so it can mix character spans (a heading's
 * metric/size span) with paragraph spans (a list item's `LeadingMarginSpan` and
 * line-spacing span).
 *
 * These signatures are designed to cover headings AND list items.
 */
interface BlockHandler {
  val blockType: BlockType

  /**
   * Spans to apply over the block's line range. Returned spans are tagged with
   * [com.swmansion.enriched.markdown.input.formatting.MarkdownSpan] so the
   * formatter can clean up only spans it created. A heading raises the font
   * size; a list item sets a leading margin and a marker. May be empty.
   */
  fun createSpans(
    blockRange: BlockRange,
    style: InputFormatterStyle,
  ): List<Any>

  /** Span classes this handler produces, for cleanup/identity (mirrors [StyleHandler.spanClasses]). */
  fun spanClasses(): List<Class<*>>

  /**
   * Markdown prefix prepended to each line of the block during serialization,
   * e.g. `"# "` for an H1 or `"- "` for a bullet. Returns `""` when the block
   * needs no prefix. Owning the marker here replaces a central serializer switch.
   */
  fun markdownLinePrefix(blockRange: BlockRange): String

  /**
   * Whether this handler claims the given parser block node, and at what level.
   * The parser asks each handler in turn so block recognition stays
   * handler-driven (mirroring how the inline pipeline maps a parser node to a
   * [com.swmansion.enriched.markdown.input.model.StyleType]). A heading handler
   * matches [MarkdownASTNode.NodeType.Heading] and reads the node's `level`
   * attribute into [outLevel].
   *
   * @param nodeType the AST block node type entered.
   * @param node the AST node (carries level/detail attributes); never null.
   * @param outLevel single-element array; on a match, set `outLevel[0]` to the
   *   level to record (0 when not applicable).
   * @return true if this handler owns the block.
   */
  fun matchesNodeType(
    nodeType: MarkdownASTNode.NodeType,
    node: MarkdownASTNode,
    outLevel: IntArray,
  ): Boolean
}
