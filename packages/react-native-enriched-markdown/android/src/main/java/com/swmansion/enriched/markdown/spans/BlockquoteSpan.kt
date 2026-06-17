package com.swmansion.enriched.markdown.spans

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.text.Layout
import android.text.Spanned
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
import android.text.style.LineBackgroundSpan
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.styles.BlockquoteStyle
import com.swmansion.enriched.markdown.utils.text.extensions.applyBlockStyleFont
import com.swmansion.enriched.markdown.utils.text.extensions.applyColorPreserving

class BlockquoteSpan(
  private val blockquoteStyle: BlockquoteStyle,
  val depth: Int,
  private val context: Context,
  private val styleCache: SpanStyleCache,
) : MetricAffectingSpan(),
  LeadingMarginSpan,
  LineBackgroundSpan {
  private val levelSpacing: Float = blockquoteStyle.borderWidth + blockquoteStyle.gapWidth
  private val blockStyle =
    BlockStyle(
      fontSize = blockquoteStyle.fontSize,
      fontFamily = blockquoteStyle.fontFamily,
      fontWeight = blockquoteStyle.fontWeight,
      color = blockquoteStyle.color,
    )

  // Cache for shouldSkipDrawing to avoid repeated getSpans() calls during draw passes
  private var cachedText: CharSequence? = null
  private var cachedMaxDepthByPosition = mutableMapOf<Int, Int>()

  override fun updateMeasureState(tp: TextPaint) = applyTextStyle(tp)

  override fun updateDrawState(tp: TextPaint) = applyTextStyle(tp)

  override fun getLeadingMargin(first: Boolean): Int = levelSpacing.toInt()

  override fun drawLeadingMargin(
    c: Canvas,
    p: Paint,
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
    // Essential check from original: only the deepest span draws to prevent over-rendering background
    if (shouldSkipDrawing(text, start)) return

    val borderPaint = configureBorderPaint()
    val borderTop = top.toFloat()
    val borderBottom = bottom.toFloat()

    for (level in 0..depth) {
      val borderX = x + (levelSpacing * level * dir)
      val borderRight = borderX + (blockquoteStyle.borderWidth * dir)
      c.drawRect(minOf(borderX, borderRight), borderTop, maxOf(borderX, borderRight), borderBottom, borderPaint)
    }
  }

  override fun drawBackground(
    canvas: Canvas,
    paint: Paint,
    left: Int,
    right: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    text: CharSequence,
    start: Int,
    end: Int,
    lineNum: Int,
  ) {
    if (shouldSkipDrawing(text, start)) return
    drawBackground(canvas, left, top, bottom, right)
  }

  @SuppressLint("WrongConstant") // Result of mask is always valid: 0, 1, 2, or 3
  private fun applyTextStyle(tp: TextPaint) {
    tp.textSize = blockStyle.fontSize
    val preserved = (tp.typeface?.style ?: 0) and BOLD_ITALIC_MASK
    tp.applyBlockStyleFont(blockStyle, context)
    if (preserved != 0) {
      tp.typeface = Typeface.create(tp.typeface ?: Typeface.DEFAULT, preserved)
    }
    tp.applyColorPreserving(blockStyle.color, *styleCache.colorsToPreserve)
  }

  companion object {
    private const val BOLD_ITALIC_MASK = Typeface.BOLD or Typeface.ITALIC

    private val sharedBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val sharedBackgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
  }

  private fun configureBorderPaint(): Paint =
    sharedBorderPaint.apply {
      color = blockquoteStyle.borderColor
    }

  private fun configureBackgroundPaint(bgColor: Int): Paint =
    sharedBackgroundPaint.apply {
      color = bgColor
    }

  private fun shouldSkipDrawing(
    text: CharSequence?,
    start: Int,
  ): Boolean {
    if (text !is Spanned) return false

    if (cachedText !== text) {
      cachedText = text
      cachedMaxDepthByPosition.clear()
    }

    val maxDepth =
      cachedMaxDepthByPosition.getOrPut(start) {
        val spans = text.getSpans(start, start + 1, BlockquoteSpan::class.java)
        spans.maxOfOrNull { it.depth } ?: -1
      }

    return maxDepth > depth
  }

  private fun drawBackground(
    c: Canvas,
    left: Int,
    top: Int,
    bottom: Int,
    right: Int,
  ) {
    val bgColor = blockquoteStyle.backgroundColor?.takeIf { it != Color.TRANSPARENT } ?: return
    val backgroundPaint = configureBackgroundPaint(bgColor)
    c.drawRect(left.toFloat(), top.toFloat(), right.toFloat(), bottom.toFloat(), backgroundPaint)
  }
}
