package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.BlockquoteSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_CONTAINER_BACKGROUND
import com.swmansion.enriched.markdown.utils.text.span.applyLineHeightSkippingImages
import com.swmansion.enriched.markdown.utils.text.span.applyMarginBottom
import com.swmansion.enriched.markdown.utils.text.span.applyMarginTop

class BlockquoteRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    if (builder.isNotEmpty() && builder.last() != '\n') {
      builder.append("\n")
    }

    val start = builder.length
    val style = config.style.blockquoteStyle
    val context = factory.blockStyleContext
    val depth = context.blockquoteDepth

    // Track depth to handle nested indentation levels
    context.blockquoteDepth = depth + 1
    context.setBlockquoteStyle(style)

    try {
      factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    } finally {
      context.popBlockStyle()
      context.blockquoteDepth = depth
    }

    if (builder.length == start) return
    val end = builder.length

    // Find immediately nested quotes to exclude them from this level's line-height/margins
    val nestedRanges =
      builder
        .getSpans(start, end, BlockquoteSpan::class.java)
        .filter { it.depth == depth + 1 }
        .map { builder.getSpanStart(it) to builder.getSpanEnd(it) }
        .sortedBy { it.first }

    // The accent bar span covers the full range for visual continuity.
    // SPAN_FLAGS_CONTAINER_BACKGROUND keeps the blockquote fill under any
    // inline chip/pill backgrounds on the same line.
    builder.setSpan(
      BlockquoteSpan(style, depth, factory.context, factory.styleCache),
      start,
      end,
      SPAN_FLAGS_CONTAINER_BACKGROUND,
    )

    // Apply line height only to segments that are NOT nested quotes, skipping
    // block images so their expanded line metrics aren't re-clamped
    applyLineHeightExcludingNested(builder, nestedRanges, start, end, style.lineHeight)

    // Margins are only applied by the outermost (root) quote
    if (depth == 0) {
      applyMarginTop(builder, start, style.marginTop)
      applyMarginBottom(builder, style.marginBottom)
    }
  }

  private fun applyLineHeightExcludingNested(
    builder: SpannableStringBuilder,
    nestedRanges: List<Pair<Int, Int>>,
    start: Int,
    end: Int,
    lineHeight: Float,
  ) {
    var currentPos = start
    for ((nestedStart, nestedEnd) in nestedRanges) {
      if (currentPos < nestedStart) {
        applyLineHeightSkippingImages(builder, currentPos, nestedStart, lineHeight)
      }
      currentPos = nestedEnd
    }
    if (currentPos < end) {
      applyLineHeightSkippingImages(builder, currentPos, end, lineHeight)
    }
  }
}
