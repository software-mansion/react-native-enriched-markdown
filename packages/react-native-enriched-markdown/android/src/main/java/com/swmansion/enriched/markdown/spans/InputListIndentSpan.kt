package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.style.LeadingMarginSpan

/**
 * Reserves the list indent (so the caret sits after the bullet) on an empty list
 * line, which has no character for an [InputBulletSpan] to attach to. Draws
 * nothing — the marker itself is painted by the view's onDraw. Removed once the
 * line gains content and a real [InputBulletSpan] takes over.
 */
class InputListIndentSpan(
  val depth: Int,
  density: Float,
) : LeadingMarginSpan {
  private val indentPerDepth = INDENT_PER_DEPTH_DP * density
  private val markerWidth = MARKER_WIDTH_DP * density

  override fun getLeadingMargin(first: Boolean): Int = (depth * indentPerDepth + markerWidth).toInt()

  override fun drawLeadingMargin(
    canvas: Canvas,
    paint: Paint,
    x: Int,
    dir: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    text: CharSequence?,
    start: Int,
    end: Int,
    first: Boolean,
    layout: Layout?,
  ) {
    // Indent only; the bullet is drawn by the view.
  }

  companion object {
    private const val INDENT_PER_DEPTH_DP = 18f
    private const val MARKER_WIDTH_DP = 18f
  }
}
