package com.swmansion.enriched.markdown.input.formatting

import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser

data class ParseResult(
  val plainText: String,
  val formattingRanges: List<FormattingRange>,
)

object InputParser {
  fun parseToPlainTextAndRanges(markdown: String): ParseResult {
    if (markdown.isEmpty()) {
      return ParseResult("", emptyList())
    }

    val completed = InputRemend.complete(markdown)
    val flags = Md4cFlags(underline = true, permissiveAutolinks = false)
    val ast = Parser.shared.parseMarkdown(completed, flags) ?: return ParseResult(markdown, emptyList())

    val plainText = StringBuilder()
    val ranges = mutableListOf<FormattingRange>()

    walkNode(ast, plainText, ranges, ArrayDeque())

    return ParseResult(plainText.toString(), ranges)
  }

  private fun walkNode(
    node: MarkdownASTNode,
    plainText: StringBuilder,
    ranges: MutableList<FormattingRange>,
    activeStyles: ArrayDeque<ActiveStyle>,
  ) {
    val styleType = nodeTypeToStyleType(node.type)

    if (styleType != null) {
      val url = if (styleType == StyleType.LINK) node.getAttribute("url") else null
      activeStyles.addLast(ActiveStyle(styleType, plainText.length, url))
    }

    if (node.type == NodeType.Text) {
      plainText.append(node.content)
    } else if (node.type == NodeType.LineBreak) {
      plainText.append("\n")
    }

    for (child in node.children) {
      walkNode(child, plainText, ranges, activeStyles)
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
