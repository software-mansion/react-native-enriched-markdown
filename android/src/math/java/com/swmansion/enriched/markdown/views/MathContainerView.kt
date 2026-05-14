package com.swmansion.enriched.markdown.views

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import com.swmansion.enriched.markdown.engines.LaidOutMath
import com.swmansion.enriched.markdown.engines.MathEngineRegistry
import com.swmansion.enriched.markdown.spans.MathMeasureHelper
import com.swmansion.enriched.markdown.spans.MathMeasureRequest
import com.swmansion.enriched.markdown.spans.MathRenderMode
import com.swmansion.enriched.markdown.styles.MathStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import kotlin.math.ceil
import kotlin.math.max

/**
 * Block-level math container.
 *
 * Architecturally identical to the previous AndroidMath-specific
 * implementation: a [HorizontalScrollView] wraps a padded view that hosts
 * the rendered formula. Only the inner view changes — instead of
 * `MTMathView` we draw whatever [LaidOutMath] the active engine produces.
 * Every external contract (long-press menu, accessibility, paddings,
 * alignment, measurement) is preserved.
 */
class MathContainerView(
  context: Context,
  styleConfig: StyleConfig,
) : FrameLayout(context),
  BlockSegmentView {
  private val mathStyle: MathStyle = styleConfig.mathStyle
  private val mathView =
    MathRenderingView(context).apply {
      val paddingPx = mathStyle.padding.toInt()
      setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
    }
  private val scrollView = HorizontalScrollView(context)
  private var cachedLatex: String = ""

  override val segmentMarginTop: Int get() = mathStyle.marginTop.toInt()
  override val segmentMarginBottom: Int get() = mathStyle.marginBottom.toInt()

  private val gravity: Int =
    when (mathStyle.textAlign) {
      "left" -> Gravity.START
      "right" -> Gravity.END
      else -> Gravity.CENTER_HORIZONTAL
    }

  init {
    setBackgroundColor(mathStyle.backgroundColor)

    val mathLayoutParams =
      LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
        this.gravity = this@MathContainerView.gravity
      }

    scrollView.apply {
      isHorizontalScrollBarEnabled = true
      overScrollMode = View.OVER_SCROLL_NEVER
      isFillViewport = true
      addView(mathView, mathLayoutParams)
    }

    addView(scrollView, LayoutParams(MATCH_PARENT, WRAP_CONTENT))

    setOnLongClickListener { view ->
      showContextMenu(view)
      true
    }
    mathView.setOnLongClickListener { view ->
      showContextMenu(view)
      true
    }
  }

  fun applyLatex(latex: String) {
    cachedLatex = latex
    mathView.bind(latex, mathStyle)
  }

  private fun showContextMenu(anchor: View) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    ContextMenuPopup.show(anchor, this) {
      item(ContextMenuPopup.Icon.COPY, "Copy") {
        clipboard.setPrimaryClip(ClipData.newPlainText("Math", cachedLatex))
      }
      item(ContextMenuPopup.Icon.DOCUMENT, "Copy as Markdown") {
        clipboard.setPrimaryClip(ClipData.newPlainText("Math", "$$\n$cachedLatex\n$$"))
      }
    }
  }

  companion object {
    fun measureMathHeight(
      latex: String,
      mathStyle: MathStyle,
      context: Context,
    ): Float {
      val request =
        MathMeasureRequest(
          fontSize = mathStyle.fontSize,
          latex = latex,
          mode = MathRenderMode.Display,
        )
      val metrics = MathMeasureHelper.measureOnMainThread(context, listOf(request)).first()
      return (metrics.ascent + metrics.descent).toInt() + (mathStyle.padding * 2)
    }
  }
}

/**
 * Engine-agnostic [View] that paints a single [LaidOutMath]. Designed to be
 * the closest possible drop-in for `MTMathView`'s previous role inside the
 * block container — set latex / style, measure, draw.
 */
private class MathRenderingView(
  context: Context,
) : View(context) {
  private var layout: LaidOutMath? = null

  fun bind(
    latex: String,
    mathStyle: MathStyle,
  ) {
    layout =
      MathEngineRegistry.get().layout(
        context = context,
        latex = latex,
        displayMode = true,
        fontSize = mathStyle.fontSize,
        color = mathStyle.color,
      )
    requestLayout()
    invalidate()
  }

  override fun onMeasure(
    widthMeasureSpec: Int,
    heightMeasureSpec: Int,
  ) {
    val l = layout
    val (contentWidth, contentHeight) =
      if (l != null) {
        ceil(l.widthPx).toInt() to ceil(l.totalHeightPx).toInt()
      } else {
        0 to 0
      }

    val width = resolveSize(contentWidth + paddingLeft + paddingRight, widthMeasureSpec)
    val height = resolveSize(contentHeight + paddingTop + paddingBottom, heightMeasureSpec)
    // `resolveSize` may clip when the parent has an exact constraint; for an
    // unconstrained width (the horizontal scroll case) we still want the full
    // formula width so horizontal scrolling kicks in.
    val finalWidth = max(width, contentWidth + paddingLeft + paddingRight)
    setMeasuredDimension(finalWidth, height)
  }

  override fun onDraw(canvas: Canvas) {
    val l = layout ?: return
    canvas.save()
    canvas.translate(paddingLeft.toFloat(), paddingTop.toFloat())
    l.drawOn(canvas)
    canvas.restore()
  }
}
