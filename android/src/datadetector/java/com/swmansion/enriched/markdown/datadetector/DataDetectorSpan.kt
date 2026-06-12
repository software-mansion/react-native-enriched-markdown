package com.swmansion.enriched.markdown.datadetector

import android.content.Context
import android.text.TextPaint
import android.text.style.ClickableSpan
import android.view.View
import android.view.ViewParent
import android.widget.FrameLayout
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.utils.text.extensions.applyBlockStyleFont
import com.swmansion.enriched.markdown.utils.text.view.emitDataDetectorPressEvent

class DataDetectorSpan(
  val entityType: String,
  val matchedText: String,
  val url: String,
  val dataJson: String,
  private val styleCache: SpanStyleCache,
  private val blockStyle: BlockStyle,
  private val context: Context,
) : ClickableSpan() {
  override fun onClick(widget: View) {
    val targetView = findReactView(widget)
    targetView?.emitDataDetectorPressEvent(entityType, matchedText, url, dataJson)
  }

  private fun findReactView(widget: View): View? {
    if (widget is EnrichedMarkdownText) return widget
    var parent: ViewParent? = widget.parent
    while (parent != null) {
      if (parent is EnrichedMarkdownText) return parent
      if (parent is FrameLayout && parent.id != View.NO_ID &&
        parent.javaClass.simpleName == "EnrichedMarkdown"
      ) {
        return parent
      }
      parent = parent.parent
    }
    return null
  }

  override fun updateDrawState(textPaint: TextPaint) {
    super.updateDrawState(textPaint)
    val fontFamily = styleCache.linkFontFamily
    if (fontFamily.isNotEmpty()) {
      val overriddenBlockStyle = blockStyle.copy(fontFamily = fontFamily)
      textPaint.applyBlockStyleFont(overriddenBlockStyle, context)
    }
    textPaint.color = styleCache.linkColor
    textPaint.isUnderlineText = styleCache.linkUnderline
  }
}
