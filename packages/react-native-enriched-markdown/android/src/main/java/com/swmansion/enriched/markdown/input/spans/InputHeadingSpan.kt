package com.swmansion.enriched.markdown.input.spans

import android.annotation.SuppressLint
import android.graphics.Typeface
import android.text.TextPaint
import android.text.style.MetricAffectingSpan
import com.facebook.react.common.ReactConstants
import com.swmansion.enriched.markdown.input.formatting.MarkdownSpan
import com.swmansion.enriched.markdown.input.model.InputFormatterStyle

/**
 * Sizes (and optionally weights/colors) a heading line in the editor per the
 * configured per-level [InputFormatterStyle.headingStyle]. Mirrors the readonly
 * renderer's `HeadingSpan` so edit and read views size headings identically.
 *
 * It is a [MetricAffectingSpan] that only adjusts the paint's text size, weight
 * and color — it never replaces the typeface family. The current bold/italic
 * style bits already set by inline spans are preserved through [BOLD_ITALIC_MASK],
 * so a bold word inside an H1 stays both big AND bold. Tagged [MarkdownSpan] so the
 * formatter cleans up only the heading spans it created, leaving inline spans intact.
 */
class InputHeadingSpan(
  val level: Int,
  style: InputFormatterStyle,
) : MetricAffectingSpan(),
  MarkdownSpan {
  private val resolved = style.headingStyle(level)

  override fun updateDrawState(tp: TextPaint) {
    applyHeadingStyle(tp)
    resolved.color?.let { tp.color = it }
  }

  override fun updateMeasureState(tp: TextPaint) {
    applyHeadingStyle(tp)
  }

  @SuppressLint("WrongConstant") // Result of mask is always valid: 0, 1, 2, or 3
  private fun applyHeadingStyle(tp: TextPaint) {
    resolved.fontSizePx?.let { tp.textSize = it }

    if (resolved.fontWeight != ReactConstants.UNSET) {
      // Fold the configured heading weight into whatever bold/italic an inline span
      // already applied, so heading weight and inline emphasis compose instead of
      // one clobbering the other.
      val inlineStyle = (tp.typeface?.style ?: 0) and BOLD_ITALIC_MASK
      val headingBold = if (resolved.fontWeight >= BOLD_WEIGHT_THRESHOLD) Typeface.BOLD else 0
      val combined = inlineStyle or headingBold
      tp.typeface =
        if (combined != 0) {
          Typeface.create(tp.typeface, combined)
        } else {
          tp.typeface
        }
    }
  }

  companion object {
    private const val BOLD_ITALIC_MASK = Typeface.BOLD or Typeface.ITALIC

    // React Native treats weights >= 700 as bold.
    private const val BOLD_WEIGHT_THRESHOLD = 700
  }
}
