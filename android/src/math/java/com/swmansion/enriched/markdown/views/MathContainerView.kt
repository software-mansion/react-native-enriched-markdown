package com.swmansion.enriched.markdown.views

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import com.swmansion.enriched.markdown.spans.MathMeasureHelper
import com.swmansion.enriched.markdown.spans.MathMeasureRequest
import com.swmansion.enriched.markdown.spans.MathRenderMode
import com.swmansion.enriched.markdown.styles.MathStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import io.ratex.RaTeXEngine
import io.ratex.RaTeXFontLoader
import io.ratex.RaTeXRenderer

class MathContainerView(
  context: Context,
  styleConfig: StyleConfig,
) : FrameLayout(context),
  BlockSegmentView {
  private val mathStyle: MathStyle = styleConfig.mathStyle
  private val scrollView = HorizontalScrollView(context)
  private var cachedLatex: String = ""

  override val segmentMarginTop: Int get() = mathStyle.marginTop.toInt()
  override val segmentMarginBottom: Int get() = mathStyle.marginBottom.toInt()

  private val mathGravity =
    when (mathStyle.textAlign) {
      "left" -> Gravity.START
      "right" -> Gravity.END
      else -> Gravity.CENTER_HORIZONTAL
    }

  private val mathView =
    object : View(context) {
      var renderer: RaTeXRenderer? = null

      override fun onMeasure(
        widthMeasureSpec: Int,
        heightMeasureSpec: Int,
      ) {
        val r = renderer
        if (r == null) {
          setMeasuredDimension(0, 0)
        } else {
          setMeasuredDimension(r.widthPx.toInt().coerceAtLeast(1), r.totalHeightPx.toInt().coerceAtLeast(1))
        }
      }

      override fun onDraw(canvas: Canvas) {
        renderer?.draw(canvas)
      }
    }

  init {
    setBackgroundColor(mathStyle.backgroundColor)

    val paddingPx = mathStyle.padding.toInt()

    RaTeXFontLoader.ensureLoaded(context)

    val mathLayoutParams =
      FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
        gravity = mathGravity
      }

    val mathWrapper =
      FrameLayout(context).apply {
        setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
      }
    mathWrapper.addView(mathView, mathLayoutParams)

    scrollView.apply {
      isHorizontalScrollBarEnabled = true
      overScrollMode = View.OVER_SCROLL_NEVER
      isFillViewport = true
      addView(mathWrapper, LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
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
    try {
      val dl = RaTeXEngine.parseBlocking(latex, displayMode = true, color = mathStyle.color)
      mathView.renderer = RaTeXRenderer(dl, mathStyle.fontSize) { RaTeXFontLoader.getTypeface(it) }
    } catch (e: Exception) {
      Log.e("MathContainerView", "Failed to render LaTeX", e)
      mathView.renderer = null
    }
    mathView.requestLayout()
    mathView.invalidate()
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
      val metrics = MathMeasureHelper.measure(context, listOf(request)).first()
      return (metrics.ascent + metrics.descent).toInt() + (mathStyle.padding * 2)
    }
  }
}
