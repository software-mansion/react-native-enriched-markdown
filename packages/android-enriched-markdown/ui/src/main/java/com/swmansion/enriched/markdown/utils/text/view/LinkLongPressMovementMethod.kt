package com.swmansion.enriched.markdown.utils.text.view

import android.os.Handler
import android.os.Looper
import android.text.Selection
import android.text.Spannable
import android.text.method.LinkMovementMethod
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.LinkSpan
import kotlin.math.abs

class LinkLongPressMovementMethod : LinkMovementMethod() {
  private val handler = Handler(Looper.getMainLooper())
  private var longPressRunnable: Runnable? = null

  private var startX = 0f
  private var startY = 0f

  var isLinkTouchActive: Boolean = false
    private set

  override fun onTouchEvent(
    widget: TextView,
    buffer: Spannable,
    event: MotionEvent,
  ): Boolean {
    when (event.action) {
      MotionEvent.ACTION_DOWN -> {
        startX = event.x
        startY = event.y

        val span = findLinkSpan(widget, buffer, event)
        isLinkTouchActive = span != null
        span?.let { scheduleLongPress(widget, it) }
      }

      MotionEvent.ACTION_MOVE -> {
        val config = ViewConfiguration.get(widget.context)
        if (abs(event.x - startX) > config.scaledTouchSlop ||
          abs(event.y - startY) > config.scaledTouchSlop
        ) {
          cancelLongPress()
          isLinkTouchActive = false
        }
      }

      MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
        cancelLongPress()
        isLinkTouchActive = false
        if (widget.hasSelection()) {
          Selection.removeSelection(buffer)
        }
      }
    }

    val result = super.onTouchEvent(widget, buffer, event)

    if (event.action == MotionEvent.ACTION_DOWN) {
      Selection.removeSelection(buffer)
    }

    return result
  }

  private fun scheduleLongPress(
    widget: TextView,
    span: LinkSpan,
  ) {
    cancelLongPress()

    longPressRunnable =
      Runnable {
        if (widget.hasSelection()) {
          Selection.removeSelection(widget.text as Spannable)
        }
        if (span.onLongClick(widget)) {
          widget.cancelLongPress()
        }
        longPressRunnable = null
      }.also {
        handler.postDelayed(it, ViewConfiguration.getLongPressTimeout().toLong())
      }
  }

  private fun cancelLongPress() {
    longPressRunnable?.let(handler::removeCallbacks)
    longPressRunnable = null
  }

  private fun charOffsetAt(
    widget: TextView,
    event: MotionEvent,
  ): Int? {
    val x = event.x.toInt() - widget.totalPaddingLeft + widget.scrollX
    val y = event.y.toInt() - widget.totalPaddingTop + widget.scrollY
    val layout = widget.layout ?: return null
    return layout.getOffsetForHorizontal(layout.getLineForVertical(y), x.toFloat())
  }

  private fun findLinkSpan(
    widget: TextView,
    buffer: Spannable,
    event: MotionEvent,
  ): LinkSpan? {
    val offset = charOffsetAt(widget, event) ?: return null
    return buffer.getSpans(offset, offset, LinkSpan::class.java).firstOrNull()
  }

  companion object {
    @JvmStatic
    fun createInstance(): LinkLongPressMovementMethod = LinkLongPressMovementMethod()
  }
}
