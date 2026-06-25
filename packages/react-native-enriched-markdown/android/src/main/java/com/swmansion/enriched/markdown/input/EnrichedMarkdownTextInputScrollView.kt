package com.swmansion.enriched.markdown.input

import android.content.Context
import android.graphics.Outline
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import androidx.core.widget.NestedScrollView
import com.facebook.react.bridge.ReadableMap

// Wraps the editor in a scroll container so contentInset behaves like iOS textContainerInset: the
// cushion is part of the scrolled content instead of clipping inside a scrolling EditText.
class EnrichedMarkdownTextInputScrollView(
  context: Context,
) : NestedScrollView(context) {
  val input = EnrichedMarkdownTextInputView(context)

  // scrollEnabled prop, for parity with iOS where false disables scrolling.
  var scrollingEnabled = true

  // RN swallows the editor's requestLayout and Fabric won't re-lay-out a fixed-height container, so
  // re-measure ourselves to update the scroll range when the editor grows.
  private val measureAndLayout =
    Runnable {
      if (width == 0 || height == 0) return@Runnable
      measure(
        MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
        MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY),
      )
      layout(left, top, right, bottom)
    }

  init {
    isFillViewport = true
    isVerticalScrollBarEnabled = true
    isVerticalFadingEdgeEnabled = false
    // RN parents default to overflow:visible and don't clip us, so clip the scrolled editor to the
    // viewport ourselves (rounded via the background outline, else a plain rect).
    outlineProvider =
      object : ViewOutlineProvider() {
        override fun getOutline(
          view: View,
          outline: Outline,
        ) {
          val background = view.background
          if (background != null) background.getOutline(outline) else outline.setRect(0, 0, view.width, view.height)
        }
      }
    clipToOutline = true
    input.scrollEnabled = false
    input.gravity = Gravity.TOP or Gravity.START
    addView(
      input,
      FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
      ),
    )
  }

  // Mirror the React tag onto the editor so its events and tag-keyed measure resolve to this component.
  override fun setId(id: Int) {
    super.setId(id)
    input.id = id
  }

  override fun onSizeChanged(
    w: Int,
    h: Int,
    oldw: Int,
    oldh: Int,
  ) {
    super.onSizeChanged(w, h, oldw, oldh)
    invalidateOutline()
  }

  override fun requestLayout() {
    super.requestLayout()
    // Only the scrolling case needs this; auto-grow is re-laid-out by Fabric. Coalesced per frame.
    if (!scrollingEnabled) return
    removeCallbacks(measureAndLayout)
    post(measureAndLayout)
  }

  override fun onInterceptTouchEvent(ev: MotionEvent): Boolean = scrollingEnabled && super.onInterceptTouchEvent(ev)

  override fun onTouchEvent(ev: MotionEvent): Boolean = scrollingEnabled && super.onTouchEvent(ev)

  override fun onDetachedFromWindow() {
    removeCallbacks(measureAndLayout)
    super.onDetachedFromWindow()
  }

  fun setContentInsetFromProps(value: ReadableMap?) {
    input.setContentInsetFromProps(value)
  }
}
