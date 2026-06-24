package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.OrderedListSpan
import com.swmansion.enriched.markdown.spans.UnorderedListSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE

class ListItemRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val styleContext = factory.blockStyleContext
    val start = builder.length
    val listType = styleContext.listType ?: return

    if (listType == BlockStyleContext.ListType.ORDERED) {
      styleContext.incrementListItemNumber()
    }

    factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)

    if (builder.length == start || builder.substring(start).isBlank()) return

    while (builder.length > start && builder.last() == '\n') {
      builder.delete(builder.length - 1, builder.length)
    }
    builder.append("\n")

    val depth = styleContext.listDepth - 1
    val listStyle = config.style.listStyle
    val itemEnd = builder.length
    val span =
      when (listType) {
        BlockStyleContext.ListType.UNORDERED -> {
          UnorderedListSpan(listStyle, depth, factory.context, factory.styleCache)
        }

        BlockStyleContext.ListType.ORDERED -> {
          OrderedListSpan(listStyle, depth, factory.context, factory.styleCache).apply {
            setItemNumber(styleContext.listItemNumber)
          }
        }
      }

    builder.setSpan(span, start, itemEnd, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
  }
}
