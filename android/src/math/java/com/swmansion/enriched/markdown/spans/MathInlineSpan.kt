package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.text.style.ReplacementSpan
import io.ratex.RaTeXEngine
import io.ratex.RaTeXFontLoader
import io.ratex.RaTeXRenderer
import kotlin.math.roundToInt

class MathInlineSpan(
  private val context: Context,
  internal val latex: String,
  internal val fontSize: Float,
  private val textColor: Int,
) : ReplacementSpan() {
  private var cachedBitmap: Bitmap? = null
  private var cachedWidth = 0
  private var mathAscent = 0f
  private var mathDescent = 0f
  private var renderFailed = false

  private fun prepareResources() {
    if (cachedBitmap != null && !cachedBitmap!!.isRecycled) return
    if (renderFailed) return

    try {
      val dl = RaTeXEngine.parseBlocking(latex, displayMode = false, color = textColor)
      val renderer = RaTeXRenderer(dl, fontSize) { RaTeXFontLoader.getTypeface(it) }

      cachedWidth = renderer.widthPx.toInt().coerceAtLeast(1)
      mathAscent = renderer.heightPx
      mathDescent = renderer.depthPx

      val bitmap =
        Bitmap.createBitmap(
          cachedWidth,
          renderer.totalHeightPx.toInt().coerceAtLeast(1),
          Bitmap.Config.ARGB_8888,
        )

      renderer.draw(Canvas(bitmap))
      cachedBitmap = bitmap
    } catch (_: Exception) {
      renderFailed = true
      val estimatedHeight = fontSize * 1.2f
      cachedWidth = (fontSize * latex.length * 0.6f).toInt().coerceAtLeast(1)
      mathAscent = estimatedHeight * 0.7f
      mathDescent = estimatedHeight * 0.3f
    }
  }

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    prepareResources()

    fm?.apply {
      ascent = -mathAscent.roundToInt()
      top = ascent
      descent = mathDescent.roundToInt()
      bottom = descent
    }

    return cachedWidth
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence?,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    prepareResources()
    cachedBitmap?.let {
      val bitmapY = y - mathAscent
      canvas.drawBitmap(it, x, bitmapY, paint)
    }
  }
}
