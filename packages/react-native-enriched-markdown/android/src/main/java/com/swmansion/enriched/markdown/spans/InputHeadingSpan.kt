package com.swmansion.enriched.markdown.spans

import android.graphics.Typeface
import android.text.TextPaint
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.markdown.input.model.BlockType

/**
 * Marker so the inline formatter (which reconciles only [MarkdownSpan]s) leaves
 * block spans untouched, letting them persist across edits the way the iOS block
 * attribute does.
 */
interface BlockSpan {
  val blockType: BlockType
}

/**
 * Editor heading span: scales the base text size and applies bold, derived from
 * whatever base font is in effect so it tracks the configured size. Acts as the
 * source of truth for a line's heading level in the input.
 */
class InputHeadingSpan(
  override val blockType: BlockType,
) : MetricAffectingSpan(),
  BlockSpan {
  private val scale: Float =
    when (blockType) {
      BlockType.HEADING_1 -> 1.6f
      BlockType.HEADING_2 -> 1.4f
      BlockType.HEADING_3 -> 1.2f
      else -> 1.0f
    }

  override fun updateDrawState(tp: TextPaint) = applyHeadingStyle(tp)

  override fun updateMeasureState(tp: TextPaint) = applyHeadingStyle(tp)

  private fun applyHeadingStyle(tp: TextPaint) {
    tp.textSize *= scale
    tp.typeface = Typeface.create(tp.typeface ?: Typeface.DEFAULT, Typeface.BOLD)
  }
}
