package com.swmansion.enriched.markdown.input.formatting

import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.FormattingRange
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

    walkNode(ast, plainText, ranges, blockRanges, ArrayDeque(), blankRuns)

    return ParseResult(plainText.toString(), ranges, blockRanges)
  }

  private fun walkNode(
    node: MarkdownASTNode,
    plainText: StringBuilder,
    ranges: MutableList<FormattingRange>,
    blockRanges: MutableList<BlockRange>,
    activeStyles: ArrayDeque<ActiveStyle>,
    blankRuns: ArrayDeque<Int>,
  ) {
    val styleType = nodeTypeToStyleType(node.type)

    if (styleType != null) {
      val url = if (styleType == StyleType.LINK) node.getAttribute("url") else null
      activeStyles.addLast(ActiveStyle(styleType, plainText.length, url))
    }

    // Headings are emitted by md4c without their `#` markers, so the content
    // captured here already excludes them — record the rendered range only.
    val headingStart = if (node.type == NodeType.Heading) plainText.length else -1

    if (node.type == NodeType.Text) {
      plainText.append(node.content)
    } else if (node.type == NodeType.LineBreak) {
      plainText.append("\n")
    }

    for ((index, child) in node.children.withIndex()) {
      // Keep the source's blank lines between top-level blocks (md4c drops them, iOS keeps them).
      if (index > 0 && child.type.isTopLevelBlock() && plainText.isNotEmpty()) {
        plainText.append("\n".repeat(blankRuns.removeFirstOrNull() ?: 2))
      }
      walkNode(child, plainText, ranges, blockRanges, activeStyles, blankRuns)
    }

    if (headingStart >= 0) {
      val level = node.getAttribute("level")?.toIntOrNull() ?: 1
      if (level in 1..3 && plainText.length > headingStart) {
        blockRanges.add(BlockRange(BlockType.forHeadingLevel(level), headingStart, plainText.length))
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
