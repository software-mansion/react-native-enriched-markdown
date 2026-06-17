package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import kotlin.math.ceil
import kotlin.math.floor
import android.text.style.LineHeightSpan as AndroidLineHeightSpan

class LineHeightSpan(
  height: Float,
) : AndroidLineHeightSpan {
  private val lineHeight: Int = ceil(height.toDouble()).toInt()

  override fun chooseHeight(
    text: CharSequence?,
    start: Int,
    end: Int,
    spanstartv: Int,
    v: Int,
    fm: Paint.FontMetricsInt?,
  ) {
    if (fm == null) return

    val leading = lineHeight - ((-fm.ascent) + fm.descent)
    fm.ascent -= ceil(leading / 2.0f).toInt()
    fm.descent += floor(leading / 2.0f).toInt()
  }
}
