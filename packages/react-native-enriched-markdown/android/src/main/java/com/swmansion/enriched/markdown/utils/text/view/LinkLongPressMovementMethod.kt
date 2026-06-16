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
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.spoiler.SpoilerCapable
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

      MotionEvent.ACTION_UP -> {
        cancelLongPress()
        isLinkTouchActive = false
        if (widget.hasSelection()) {
          Selection.removeSelection(buffer)
        }
        if (handleSpoilerTap(widget, buffer, event)) {
          Selection.removeSelection(buffer)
          return true
        }
      }

      MotionEvent.ACTION_CANCEL -> {
        cancelLongPress()
        isLinkTouchActive = false
        if (widget.hasSelection()) {
          Selection.removeSelection(buffer)
        }
      }
    }

    val result = super.onTouchEvent(widget, buffer, event)

    // LinkMovementMethod sets a Selection highlight around the link on ACTION_DOWN,
    // which causes a visible selection color on the link text while pressed.
    // We remove that selection immediately so the user never sees it.
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
        // Execute the long click logic on the span
        if (span.onLongClick(widget)) {
          // If consumed, cancel the system's own long-press logic (like context menus)
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

  private fun handleSpoilerTap(
    widget: TextView,
    buffer: Spannable,
    event: MotionEvent,
  ): Boolean {
    val offset = charOffsetAt(widget, event) ?: return false
    val tappedSpan =
      buffer
        .getSpans(offset, offset, SpoilerSpan::class.java)
        .firstOrNull { !it.revealed && !it.revealing } ?: return false

    val drawer = (widget as? SpoilerCapable)?.spoilerOverlayDrawer ?: return false
    val spans = expandContiguousSpoilers(buffer, tappedSpan)
    val remaining = intArrayOf(spans.size)

    for (span in spans) {
      drawer.revealSpan(span) {
        remaining[0]--
        if (remaining[0] <= 0) widget.invalidate()
      }
    }
    widget.invalidate()
    return true
  }

  private fun expandContiguousSpoilers(
    buffer: Spannable,
    seed: SpoilerSpan,
  ): List<SpoilerSpan> {
    val allSpans = buffer.getSpans(0, buffer.length, SpoilerSpan::class.java)
    if (allSpans.size <= 1) return listOf(seed)

    val result = mutableSetOf(seed)
    var rangeStart = buffer.getSpanStart(seed)
    var rangeEnd = buffer.getSpanEnd(seed)
    var changed = true
    while (changed) {
      changed = false
      for (span in allSpans) {
        if (span in result) continue
        val spanStart = buffer.getSpanStart(span)
        val spanEnd = buffer.getSpanEnd(span)
        if (spanEnd >= rangeStart && spanStart <= rangeEnd) {
          result.add(span)
          if (spanStart < rangeStart) rangeStart = spanStart
          if (spanEnd > rangeEnd) rangeEnd = spanEnd
          changed = true
        }
      }
    }
    return result.sortedBy { buffer.getSpanStart(it) }
  }

  companion object {
    @JvmStatic
    fun createInstance(): LinkLongPressMovementMethod = LinkLongPressMovementMethod()
  }
}
