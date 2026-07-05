package com.swmansion.enriched.markdown.input.formatting

import android.text.Spannable
import android.text.style.CharacterStyle
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.InputFormatterStyle
import com.swmansion.enriched.markdown.input.model.StyleType
import com.swmansion.enriched.markdown.input.styles.BlockHandler
import com.swmansion.enriched.markdown.input.styles.BoldStyleHandler
import com.swmansion.enriched.markdown.input.styles.HeadingBlockHandler
import com.swmansion.enriched.markdown.input.styles.ItalicStyleHandler
import com.swmansion.enriched.markdown.input.styles.LinkStyleHandler
import com.swmansion.enriched.markdown.input.styles.SpoilerStyleHandler
import com.swmansion.enriched.markdown.input.styles.StrikethroughStyleHandler
import com.swmansion.enriched.markdown.input.styles.StyleHandler
import com.swmansion.enriched.markdown.input.styles.UnderlineStyleHandler

/**
 * Marker interface so we only remove spans we created, leaving
 * system spans (IME underline, selection highlight) untouched.
 */
interface MarkdownSpan

class InputFormatter {
  val handlers: Map<StyleType, StyleHandler> =
    mapOf(
      StyleType.BOLD to BoldStyleHandler(),
      StyleType.ITALIC to ItalicStyleHandler(),
      StyleType.UNDERLINE to UnderlineStyleHandler(),
      StyleType.STRIKETHROUGH to StrikethroughStyleHandler(),
      StyleType.LINK to LinkStyleHandler(),
      StyleType.SPOILER to SpoilerStyleHandler(),
    )

  /**
   * Block handlers, keyed by block type. A single [HeadingBlockHandler] serves all
   * six heading levels — it reads the level from the [BlockRange] — so it is mapped
   * under every `HEADING_n` key.
   */
  val blockHandlers: Map<BlockType, BlockHandler> =
    HeadingBlockHandler().let { heading ->
      BlockType.HEADINGS.associateWith { heading }
    }

  fun handlerForBlock(type: BlockType): BlockHandler? = blockHandlers[type]

  private var style: InputFormatterStyle? = null

  fun updateStyle(newStyle: InputFormatterStyle): Boolean {
    if (newStyle == style) return false
    style = newStyle
    return true
  }

  fun resolveHeadingFontSizePx(level: Int): Float? = style?.headingStyle(level)?.fontSizePx

  fun applyFormatting(
    spannable: Spannable,
    ranges: List<FormattingRange>,
  ) {
    val currentStyle = style ?: return

    val blockSpanClasses = blockHandlers.values.flatMap { it.spanClasses() }.toSet()
    val existingSpans =
      spannable
        .getSpans(0, spannable.length, CharacterStyle::class.java)
        .filterIsInstance<MarkdownSpan>()
        .filter { span -> blockSpanClasses.none { it.isInstance(span) } }
    val linkSpanClasses = handlers[StyleType.LINK]?.spanClasses().orEmpty().toSet()
    val existingLinkSpans = existingSpans.filter { span -> linkSpanClasses.any { it.isInstance(span) } }
    for (span in existingLinkSpans) {
      spannable.removeSpan(span as CharacterStyle)
    }

    val desired = mutableListOf<SpanDescriptor>()
    for (range in ranges) {
      if (range.start >= range.end || range.start < 0 || range.end > spannable.length) continue
      val handler = handlers[range.type] ?: continue
      val spans = handler.createSpans(range, currentStyle)
      for (span in spans) {
        desired.add(SpanDescriptor(range.start, range.end, span::class.java, range.url))
      }
    }

    val existing =
      existingSpans
        .filter { span -> span !in existingLinkSpans }
        .map { span ->
          SpanDescriptor(
            spannable.getSpanStart(span as CharacterStyle),
            spannable.getSpanEnd(span as CharacterStyle),
            span::class.java,
            null,
          ) to (span as CharacterStyle)
        }

    val desiredSet = desired.toSet()
    val existingSet = existing.map { it.first }.toSet()

    if (desiredSet == existingSet) return

    for ((desc, span) in existing) {
      if (desc !in desiredSet) {
        spannable.removeSpan(span)
      }
    }

    for (desc in desired) {
      if (desc !in existingSet) {
        val handler =
          handlers.values.firstOrNull { h ->
            h.spanClasses().any { it == desc.spanClass }
          } ?: continue
        val dummyRange = FormattingRange(handler.styleType, desc.start, desc.end, desc.url)
        val newSpans = handler.createSpans(dummyRange, currentStyle)
        val matchingSpan = newSpans.firstOrNull { it::class.java == desc.spanClass }
        if (matchingSpan != null) {
          spannable.setSpan(
            matchingSpan,
            desc.start,
            desc.end,
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
          )
        }
      }
    }
  }

  /**
   * Applies each block range's paragraph-scoped spans via its handler, after the
   * inline pass. Mirrors [applyFormatting]: removes the block spans we previously
   * set (identified by the registered handlers' [BlockHandler.spanClasses]) and
   * re-applies from the current ranges. With no handlers registered (PR1) both
   * the cleanup and the apply loops are no-ops, so block formatting is inert.
   */
  fun applyBlockFormatting(
    spannable: Spannable,
    blockRanges: List<BlockRange>,
  ) = applyBlockFormatting(spannable, blockRanges, 0, spannable.length)

  /**
   * Re-stamps block spans, scoped to `[scopeStart, scopeEnd)`. Only the block spans
   * we created that intersect the scope are removed, and only the block ranges
   * intersecting the scope are re-applied — so an edit re-normalizes just the
   * affected line(s) instead of the whole document on every keystroke. Pass the
   * full document range for a wholesale re-apply (import / style change).
   */
  fun applyBlockFormatting(
    spannable: Spannable,
    blockRanges: List<BlockRange>,
    scopeStart: Int,
    scopeEnd: Int,
  ) {
    val currentStyle = style ?: return
    if (blockHandlers.isEmpty()) return

    val start = scopeStart.coerceIn(0, spannable.length)
    val end = scopeEnd.coerceIn(start, spannable.length)

    val blockSpanClasses = blockHandlers.values.flatMap { it.spanClasses() }.toSet()

    val existingBlockSpans =
      spannable
        .getSpans(start, end, Any::class.java)
        .filter { span -> span is MarkdownSpan && blockSpanClasses.any { it.isInstance(span) } }
    for (span in existingBlockSpans) {
      spannable.removeSpan(span)
    }

    for (range in blockRanges) {
      val isHeadingAnchor = range.length == 0 && range.type in BlockType.HEADINGS
      if (!isHeadingAnchor && (range.start >= range.end || range.start < 0 || range.end > spannable.length)) continue
      if (isHeadingAnchor && (range.start < 0 || range.start > spannable.length)) continue
      if (isHeadingAnchor) {
        if (range.start < start || range.start > end) continue
      } else if (range.end <= start || range.start >= end) {
        continue
      }
      val handler = blockHandlers[range.type] ?: continue

      // Extend a zero-length heading anchor to cover the next character (usually
      // '\n') so the Layout gives the empty line heading metrics. At the very end
      // of text the span stays zero-length; the view-level paint override handles
      // cursor height for that edge case.
      val spanEnd = if (isHeadingAnchor && range.start < spannable.length) range.start + 1 else range.end
      val flags = if (isHeadingAnchor) Spannable.SPAN_INCLUSIVE_INCLUSIVE else Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
      for (span in handler.createSpans(range, currentStyle)) {
        spannable.setSpan(span, range.start, spanEnd, flags)
      }
    }
  }

  private data class SpanDescriptor(
    val start: Int,
    val end: Int,
    val spanClass: Class<*>,
    val url: String?,
  )
}
