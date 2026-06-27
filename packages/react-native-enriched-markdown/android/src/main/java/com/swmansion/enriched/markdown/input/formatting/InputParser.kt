package com.swmansion.enriched.markdown.input.formatting

import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.MAX_LIST_DEPTH
import com.swmansion.enriched.markdown.input.model.StyleType
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.parser.isTopLevelBlock

data class ParseResult(
  val plainText: String,
  val formattingRanges: List<FormattingRange>,
  val blockRanges: List<BlockRange> = emptyList(),
)

object InputParser {
  // A source paragraph break: a newline followed by one or more blank lines.
  private val PARAGRAPH_BREAK_RE = Regex("\\n[ \\t]*(?:\\n[ \\t]*)+")

  fun parseToPlainTextAndRanges(markdown: String): ParseResult {
    if (markdown.isEmpty()) {
      return ParseResult("", emptyList())
    }

    val completed = InputRemend.complete(markdown)
    val flags = Md4cFlags(underline = true, permissiveAutolinks = false)
    val ast = Parser.shared.parseMarkdown(completed, flags) ?: return ParseResult(markdown, emptyList())

    val plainText = StringBuilder()
    val ranges = mutableListOf<FormattingRange>()
    val blockRanges = mutableListOf<BlockRange>()

    // md4c collapses any blank-line run into a single break, unlike iOS which keeps them.
    // Re-read the real runs so each break replays its original number of newlines.
    val blankRuns =
      ArrayDeque(
        PARAGRAPH_BREAK_RE
          .findAll(completed.trim())
          .map { match -> match.value.count { it == '\n' } }
          .toList(),
      )

    walkNode(ast, plainText, ranges, blockRanges, ArrayDeque(), blankRuns, 0)

    return ParseResult(plainText.toString(), ranges, blockRanges)
  }

  private fun walkNode(
    node: MarkdownASTNode,
    plainText: StringBuilder,
    ranges: MutableList<FormattingRange>,
    blockRanges: MutableList<BlockRange>,
    activeStyles: ArrayDeque<ActiveStyle>,
    blankRuns: ArrayDeque<Int>,
    listDepth: Int,
  ) {
    val styleType = nodeTypeToStyleType(node.type)

    if (styleType != null) {
      val url = if (styleType == StyleType.LINK) node.getAttribute("url") else null
      activeStyles.addLast(ActiveStyle(styleType, plainText.length, url))
    }

    // An unordered list increments the nesting depth for its items. A list item
    // captures its own first line (its text precedes any nested sublist).
    val childListDepth = if (node.type == NodeType.UnorderedList) listDepth + 1 else listDepth

    // Each list item starts on its own line; md4c emits no separator between
    // sibling items or before a nested sublist.
    if (node.type == NodeType.ListItem && plainText.isNotEmpty() && !plainText.endsWith("\n")) {
      plainText.append("\n")
    }
    val itemStart = if (node.type == NodeType.ListItem) plainText.length else -1

    if (node.type == NodeType.Text) {
      plainText.append(node.content)
    } else if (node.type == NodeType.LineBreak) {
      plainText.append("\n")
    }

    for ((index, child) in node.children.withIndex()) {
      // Keep the source's blank lines between genuinely top-level blocks (md4c
      // drops them, iOS keeps them). Inside a list, items are separated by a
      // single newline above, not blank lines.
      if (index > 0 && listDepth == 0 && child.type.isTopLevelBlock() && plainText.isNotEmpty()) {
        plainText.append("\n".repeat(blankRuns.removeFirstOrNull() ?: 2))
      }
      walkNode(child, plainText, ranges, blockRanges, activeStyles, blankRuns, childListDepth)
    }

    if (itemStart >= 0) {
      // The item's own line ends at the first newline after its start (nested
      // sublists live on later lines).
      var lineEnd = plainText.indexOf('\n', itemStart)
      if (lineEnd < 0) lineEnd = plainText.length
      if (lineEnd > itemStart) {
        val depth = (listDepth - 1).coerceIn(0, MAX_LIST_DEPTH)
        blockRanges.add(BlockRange(BlockType.UNORDERED_LIST_ITEM, itemStart, lineEnd, depth))
      }
    }

    if (styleType != null) {
      val activeStyle = activeStyles.removeLast()
      val end = plainText.length
      if (end > activeStyle.startPosition) {
        ranges.add(FormattingRange(styleType, activeStyle.startPosition, end, activeStyle.url))
      }
    }
  }

  private fun nodeTypeToStyleType(nodeType: NodeType): StyleType? =
    when (nodeType) {
      NodeType.Strong -> StyleType.BOLD
      NodeType.Emphasis -> StyleType.ITALIC
      NodeType.Underline -> StyleType.UNDERLINE
      NodeType.Strikethrough -> StyleType.STRIKETHROUGH
      NodeType.Link -> StyleType.LINK
      NodeType.Spoiler -> StyleType.SPOILER
      else -> null
    }

  private data class ActiveStyle(
    val type: StyleType,
    val startPosition: Int,
    val url: String?,
  )
}
