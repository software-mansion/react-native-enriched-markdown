package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.Spanned
import android.text.style.LeadingMarginSpan
import com.swmansion.enriched.markdown.input.model.BlockType

/**
 * Marker so list state can be discovered without depending on a concrete span
 * type. A [LeadingMarginSpan] is a paragraph span, so the inline formatter (which
 * reconciles only [CharacterStyle] [MarkdownSpan]s) never touches it — it
 * persists across edits, acting as the source of truth for a line's list depth.
 */
interface BlockSpan {
  val blockType: BlockType
  val depth: Int
}

/** Editor unordered-list span: reserves a per-depth indent and draws the bullet. */
class InputBulletSpan(
  override val depth: Int,
  density: Float,
) : LeadingMarginSpan,
  BlockSpan {
  override val blockType: BlockType = BlockType.UNORDERED_LIST_ITEM

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
    if (!first) return
    // Only draw on the line where this span starts (wrapped lines also get first=true).
    if (text is Spanned && text.getSpanStart(this) != start) return

    val size = (paint.textSize * 0.3f).coerceAtLeast(4f)
    val radius = size / 2f
    val centerX = x + (depth * indentPerDepth + markerWidth * 0.5f) * dir
    val fm = paint.fontMetrics
    val centerY = baseline + (fm.ascent + fm.descent) / 2f

    val originalStyle = paint.style
    val originalStrokeWidth = paint.strokeWidth
    when (depth % 3) {
      0 -> {
        paint.style = Paint.Style.FILL
        canvas.drawCircle(centerX, centerY, radius, paint)
      }

      1 -> {
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = (size * 0.15f).coerceAtLeast(1f)
        canvas.drawCircle(centerX, centerY, radius - paint.strokeWidth / 2f, paint)
      }

      else -> {
        paint.style = Paint.Style.FILL
        canvas.drawRect(centerX - radius, centerY - radius, centerX + radius, centerY + radius, paint)
      }
    }
    paint.style = originalStyle
    paint.strokeWidth = originalStrokeWidth
  }

  companion object {
    private const val INDENT_PER_DEPTH_DP = 18f
    private const val MARKER_WIDTH_DP = 18f
  }
}
