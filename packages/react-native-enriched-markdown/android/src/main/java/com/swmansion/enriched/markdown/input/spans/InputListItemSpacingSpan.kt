package com.swmansion.enriched.markdown.input.spans

import android.graphics.Paint
import android.text.style.LineHeightSpan
import com.swmansion.enriched.markdown.input.formatting.MarkdownSpan

/**
 * Adds [spacingPx] of vertical space above a bullet item (counterpart to iOS
 * `paragraphSpacingBefore`). Must span only the item's first character so wrapped
 * continuation lines aren't spaced. Tagged [MarkdownSpan] for formatter cleanup.
 */
class InputListItemSpacingSpan(
  val spacingPx: Int,
) : LineHeightSpan,
  MarkdownSpan {
  override fun chooseHeight(
    text: CharSequence?,
    start: Int,
    end: Int,
    spanstartv: Int,
    lineHeight: Int,
    fm: Paint.FontMetricsInt?,
  ) {
    if (fm == null || spacingPx <= 0) return
    fm.ascent -= spacingPx
    fm.top -= spacingPx
  }
}
