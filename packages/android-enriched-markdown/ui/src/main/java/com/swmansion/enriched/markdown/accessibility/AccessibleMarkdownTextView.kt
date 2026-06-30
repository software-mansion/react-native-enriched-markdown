package com.swmansion.enriched.markdown.accessibility

import android.content.Context
import android.graphics.Rect
import android.util.AttributeSet
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.appcompat.widget.AppCompatTextView

/** AppCompatTextView with built-in TalkBack support via MarkdownAccessibilityHelper. */
abstract class AccessibleMarkdownTextView
  @JvmOverloads
  constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
  ) : AppCompatTextView(context, attrs, defStyleAttr) {
    val accessibilityHelper = MarkdownAccessibilityHelper(this)

    override fun dispatchHoverEvent(event: MotionEvent): Boolean =
      accessibilityHelper.dispatchHoverEvent(event) || super.dispatchHoverEvent(event)

    override fun dispatchKeyEvent(event: KeyEvent): Boolean = accessibilityHelper.dispatchKeyEvent(event) || super.dispatchKeyEvent(event)

    override fun onFocusChanged(
      gainFocus: Boolean,
      direction: Int,
      previouslyFocusedRect: Rect?,
    ) {
      super.onFocusChanged(gainFocus, direction, previouslyFocusedRect)
      accessibilityHelper.onFocusChanged(gainFocus, direction, previouslyFocusedRect)
    }
  }
