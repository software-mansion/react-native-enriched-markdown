package com.swmansion.enriched.markdown.spans

import android.graphics.Color
import android.text.TextPaint
import android.text.style.CharacterStyle
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache

/**
 * Applies highlight foreground/background only. Must not reset typeface or text size so nested
 * strong/emphasis spans inside ==highlight== keep working (MetricAffectingSpan would overwrite them).
 */
class HighlightSpan(
  private val styleCache: SpanStyleCache,
  private val blockStyle: BlockStyle,
) : CharacterStyle() {
  private val foregroundColor = styleCache.getHighlightColorFor(blockStyle.color)

  override fun updateDrawState(textPaint: TextPaint) {
    textPaint.color = foregroundColor
    val backgroundColor = styleCache.highlightBackgroundColor
    if (Color.alpha(backgroundColor) > 0) {
      textPaint.bgColor = backgroundColor
    }
  }
}
