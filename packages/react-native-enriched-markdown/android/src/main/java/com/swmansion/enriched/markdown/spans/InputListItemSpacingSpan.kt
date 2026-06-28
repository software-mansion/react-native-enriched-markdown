package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import android.text.style.LineHeightSpan

/**
 * Adds [spacingPx] of vertical space above a list item so bullets read as
 * separate rows. Apply it to only the first character of the item's line so it
 * affects just the first visual line (not wrapped continuations); [chooseHeight]
 * runs per visual line and only the first one intersects that single-char range.
 */
class InputListItemSpacingSpan(
  val spacingPx: Int,
) : LineHeightSpan {
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
