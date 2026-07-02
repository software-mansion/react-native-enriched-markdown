package com.swmansion.enriched.markdown.input.layout

import android.content.Context
import android.graphics.Rect
import android.os.Build
import android.text.StaticLayout
import android.text.TextPaint
import androidx.appcompat.widget.AppCompatEditText
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.PixelUtil
import com.facebook.yoga.YogaMeasureMode
import com.facebook.yoga.YogaMeasureOutput
import com.swmansion.enriched.markdown.input.formatting.InputParser
import java.util.concurrent.ConcurrentHashMap

object InputMeasurementStore {
  private data class PaintParams(
    val typeface: android.graphics.Typeface?,
    val fontSize: Float,
  )

  private data class MeasurementParams(
    val cachedWidth: Float,
    val cachedSize: Long,
    val text: CharSequence?,
    val paintParams: PaintParams,
    val inset: Rect,
  )

  private val data = ConcurrentHashMap<Int, MeasurementParams>()

  fun store(
    id: Int,
    text: CharSequence?,
    paint: TextPaint,
    inset: Rect,
  ): Boolean {
    val cachedWidth = data[id]?.cachedWidth ?: 0f
    val cachedSize = data[id]?.cachedSize ?: 0L

    val size = measure(cachedWidth, text, paint, inset)
    val paintParams = PaintParams(paint.typeface, paint.textSize)

    data[id] = MeasurementParams(cachedWidth, size, text, paintParams, inset)
    return size != cachedSize
  }

  fun release(id: Int) {
    data.remove(id)
  }

  fun getMeasureById(
    context: Context,
    id: Int?,
    width: Float,
    height: Float,
    heightMode: YogaMeasureMode?,
    props: ReadableMap?,
  ): Long {
    val size = getMeasureByIdInternal(context, id, width, props)
    // EXACTLY = fixed frame: fill it and let the container scroll the editor, not collapse to content.
    if (heightMode === YogaMeasureMode.EXACTLY) {
      return YogaMeasureOutput.make(YogaMeasureOutput.getWidth(size), PixelUtil.toDIPFromPixel(height))
    }
    if (heightMode !== YogaMeasureMode.AT_MOST) {
      return size
    }

    val calculatedHeight = YogaMeasureOutput.getHeight(size)
    val atMostHeight = PixelUtil.toDIPFromPixel(height)
    val finalHeight = calculatedHeight.coerceAtMost(atMostHeight)
    return YogaMeasureOutput.make(YogaMeasureOutput.getWidth(size), finalHeight)
  }

  private fun getMeasureByIdInternal(
    context: Context,
    id: Int?,
    width: Float,
    props: ReadableMap?,
  ): Long {
    if (id == null) return initialMeasure(context, width, props)
    val value = data[id] ?: return initialMeasure(context, width, props)

    if (width == value.cachedWidth) {
      return value.cachedSize
    }

    val paint =
      TextPaint().apply {
        typeface = value.paintParams.typeface
        textSize = value.paintParams.fontSize
      }

    val size = measure(width, value.text, paint, value.inset)
    data[id] = MeasurementParams(width, size, value.text, value.paintParams, value.inset)
    return size
  }

  private fun initialMeasure(
    context: Context,
    width: Float,
    props: ReadableMap?,
  ): Long {
    // Measure the rendered plain text, not the raw markdown. A mention link such as
    // [Label](placeholder://x) hides its URL in the source, so measuring the markdown counts those
    // invisible characters and over-estimates the height into extra lines, until the next text
    // change forces a re-measure. Parsing first matches what the editor actually renders.
    val markdown = props?.getString("defaultValue") ?: props?.getString("placeholder") ?: "I"
    val text = InputParser.parseToPlainTextAndRanges(markdown).plainText
    val fontSize = props?.getDouble("fontSize")?.toFloat() ?: 16f
    val spSize = kotlin.math.ceil(PixelUtil.toPixelFromSP(fontSize).toDouble()).toFloat()

    val defaultView = AppCompatEditText(context)
    val paint =
      TextPaint(defaultView.paint).apply {
        textSize = spSize
        isAntiAlias = true
      }

    return measure(width, text, paint, insetFromProps(props))
  }

  private fun insetFromProps(props: ReadableMap?): Rect {
    val inset = props?.getMap("contentInset") ?: return Rect()

    fun px(key: String): Int = if (inset.hasKey(key)) PixelUtil.toPixelFromDIP(inset.getDouble(key).toFloat()).toInt() else 0
    return Rect(px("left"), px("top"), px("right"), px("bottom"))
  }

  private fun measure(
    maxWidth: Float,
    text: CharSequence?,
    paint: TextPaint,
    inset: Rect,
  ): Long {
    val content = text ?: ""
    // The text wraps inside the horizontal inset and the vertical inset is added back below, so the
    // reported height matches the padded EditText exactly and nothing clips.
    val widthPx = (maxWidth.toInt() - inset.left - inset.right).coerceAtLeast(0)

    val builder =
      StaticLayout.Builder
        .obtain(content, 0, content.length, paint, widthPx)
        .setIncludePad(true)
        .setLineSpacing(0f, 1f)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      builder.setBreakStrategy(android.graphics.text.LineBreaker.BREAK_STRATEGY_HIGH_QUALITY)
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      builder.setUseLineSpacingFromFallbacks(true)
    }

    val staticLayout = builder.build()
    val heightInDip = PixelUtil.toDIPFromPixel((staticLayout.height + inset.top + inset.bottom).toFloat())
    val widthInDip = PixelUtil.toDIPFromPixel(maxWidth)
    return YogaMeasureOutput.make(widthInDip, heightInDip)
  }
}
