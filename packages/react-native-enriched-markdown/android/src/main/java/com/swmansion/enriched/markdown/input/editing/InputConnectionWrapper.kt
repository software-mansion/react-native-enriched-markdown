package com.swmansion.enriched.markdown.input.editing

import android.view.KeyEvent
import android.view.inputmethod.InputConnection
import com.swmansion.enriched.markdown.input.EnrichedMarkdownTextInputView
import android.view.inputmethod.InputConnectionWrapper as AndroidInputConnectionWrapper

class InputConnectionWrapper(
  target: InputConnection,
  private val editText: EnrichedMarkdownTextInputView,
) : AndroidInputConnectionWrapper(target, false) {
  var isBatchEdit = false
    private set

  override fun beginBatchEdit(): Boolean {
    isBatchEdit = true
    return super.beginBatchEdit()
  }

  override fun endBatchEdit(): Boolean {
    isBatchEdit = false
    return super.endBatchEdit()
  }

  override fun setComposingText(
    text: CharSequence,
    newCursorPosition: Int,
  ): Boolean = super.setComposingText(text, newCursorPosition)

  override fun commitText(
    text: CharSequence,
    newCursorPosition: Int,
  ): Boolean = super.commitText(text, newCursorPosition)

  override fun deleteSurroundingText(
    beforeLength: Int,
    afterLength: Int,
  ): Boolean {
    if (beforeLength == 1 && afterLength == 0 && editText.deleteLinkBeforeCursor()) {
      return true
    }
    return super.deleteSurroundingText(beforeLength, afterLength)
  }

  override fun sendKeyEvent(event: KeyEvent): Boolean {
    if (event.action == KeyEvent.ACTION_DOWN &&
      event.keyCode == KeyEvent.KEYCODE_DEL &&
      editText.deleteLinkBeforeCursor()
    ) {
      return true
    }
    return super.sendKeyEvent(event)
  }
}
