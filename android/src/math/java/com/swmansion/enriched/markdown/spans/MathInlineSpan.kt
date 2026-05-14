package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.engines.LaidOutMath
import com.swmansion.enriched.markdown.engines.MathEngineRegistry
import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * Inline math attachment. Participates in Android's text layout as a single
 * replacement character; the surrounding `TextView` handles line breaking,
 * baseline alignment, justification and bidi.
 *
 * The actual parse + layout is delegated to the selected [com.swmansion.enriched.markdown.engines.MathEngine]
 * (either AndroidMath, the default, or RaTeX when `enrichedMarkdown.mathEngine=ratex`).
 * If the engine fails to parse the input we collapse to zero width so the
 * paragraph still flows cleanly — host apps are expected to pre-process the
 * markdown source for known-unsupported macros if they want a visible
 * indicator.
 */
class MathInlineSpan(
  private val context: Context,
  internal val latex: String,
  internal val fontSize: Float,
  private val textColor: Int,
) : ReplacementSpan() {
  private var layout: LaidOutMath? = null
  private var didAttemptLayout: Boolean = false

  private fun prepareIfNeeded() {
    if (didAttemptLayout) return
    didAttemptLayout = true

    layout =
      MathEngineRegistry.get().layout(
        context = context,
        latex = latex,
        displayMode = false,
        fontSize = fontSize,
        color = textColor,
      )
  }

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    prepareIfNeeded()

    val l = layout
    if (l == null) {
      fm?.apply {
        ascent = 0
        top = 0
        descent = 0
        bottom = 0
      }
      return 0
    }

    fm?.apply {
      ascent = -ceil(l.ascentPx).toInt()
      top = ascent
      descent = ceil(l.descentPx).toInt()
      bottom = descent
    }
    return ceil(l.widthPx).roundToInt()
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
    prepareIfNeeded()
    val l = layout ?: return

    canvas.save()
    // `y` is the text baseline. The engine paints from the top-left of its
    // bounding box, so translate so that top sits `ascentPx` above the
    // baseline.
    canvas.translate(x, y - l.ascentPx)
    l.drawOn(canvas)
    canvas.restore()
  }
}
