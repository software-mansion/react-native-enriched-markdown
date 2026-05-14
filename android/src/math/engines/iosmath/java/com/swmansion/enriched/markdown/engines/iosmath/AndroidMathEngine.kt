package com.swmansion.enriched.markdown.engines.iosmath

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View.MeasureSpec
import com.agog.mathdisplay.MTMathView
import com.swmansion.enriched.markdown.engines.LaidOutMath
import com.swmansion.enriched.markdown.engines.MathEngine

/**
 * AndroidMath-backed math engine. Selected at build time when
 * `enrichedMarkdown.mathEngine` is unset or `androidmath` (the default).
 *
 * AndroidMath exposes its `MTMathView.displayList` as a private field; we
 * reach in via reflection to pull baseline-accurate ascent/descent metrics
 * instead of estimating from the measured view height. This matches what
 * the previous `MathInlineSpan` did, only now wrapped behind the
 * [MathEngine] contract so non-engine code stays generic.
 */
class AndroidMathEngine : MathEngine {
  override fun layout(
    context: Context,
    latex: String,
    displayMode: Boolean,
    fontSize: Float,
    color: Int,
  ): LaidOutMath? {
    if (latex.isEmpty()) return null

    val mathView =
      MTMathView(context).apply {
        labelMode =
          if (displayMode) {
            MTMathView.MTMathViewMode.KMTMathViewModeDisplay
          } else {
            MTMathView.MTMathViewMode.KMTMathViewModeText
          }
        textAlignment = MTMathView.MTTextAlignment.KMTTextAlignmentLeft
        this.fontSize = fontSize
        this.textColor = color
        this.latex = latex
      }

    val spec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
    mathView.measure(spec, spec)

    val width = mathView.measuredWidth.coerceAtLeast(1)
    val height = mathView.measuredHeight.coerceAtLeast(1)
    mathView.layout(0, 0, width, height)

    val (ascent, descent) = readDisplayListMetrics(mathView, height.toFloat())

    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    mathView.draw(Canvas(bitmap))

    return AndroidMathLayout(
      bitmap = bitmap,
      widthPx = width.toFloat(),
      ascentPx = ascent,
      descentPx = descent,
    )
  }

  private fun readDisplayListMetrics(
    view: MTMathView,
    height: Float,
  ): Pair<Float, Float> =
    try {
      val dl = DISPLAY_LIST_FIELD?.get(view)
      if (dl != null) {
        val ascent = GET_ASCENT_METHOD?.invoke(dl) as? Float ?: (height * 0.7f)
        val descent = GET_DESCENT_METHOD?.invoke(dl) as? Float ?: (height * 0.3f)
        ascent to descent
      } else {
        (height * 0.7f) to (height * 0.3f)
      }
    } catch (_: Exception) {
      (height * 0.7f) to (height * 0.3f)
    }

  companion object {
    private val DISPLAY_LIST_FIELD =
      runCatching {
        MTMathView::class.java.getDeclaredField("displayList").apply { isAccessible = true }
      }.getOrNull()

    private val GET_ASCENT_METHOD =
      runCatching {
        DISPLAY_LIST_FIELD?.type?.getMethod("getAscent")
      }.getOrNull()

    private val GET_DESCENT_METHOD =
      runCatching {
        DISPLAY_LIST_FIELD?.type?.getMethod("getDescent")
      }.getOrNull()
  }
}

private class AndroidMathLayout(
  private val bitmap: Bitmap,
  override val widthPx: Float,
  override val ascentPx: Float,
  override val descentPx: Float,
) : LaidOutMath {
  override fun drawOn(canvas: Canvas) {
    canvas.drawBitmap(bitmap, 0f, 0f, null)
  }
}
