package com.swmansion.enriched.markdown.input.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class OnChangeStateEvent(
  surfaceId: Int,
  viewId: Int,
  private val isBold: Boolean,
  private val isItalic: Boolean,
  private val isUnderline: Boolean,
  private val isStrikethrough: Boolean,
  private val isSpoiler: Boolean,
  private val isLink: Boolean,
) : Event<OnChangeStateEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap =
    Arguments.createMap().apply {
      putMap(
        "bold",
        Arguments.createMap().apply { putBoolean("isActive", isBold) },
      )
      putMap(
        "italic",
        Arguments.createMap().apply { putBoolean("isActive", isItalic) },
      )
      putMap(
        "underline",
        Arguments.createMap().apply { putBoolean("isActive", isUnderline) },
      )
      putMap(
        "strikethrough",
        Arguments.createMap().apply { putBoolean("isActive", isStrikethrough) },
      )
      putMap(
        "spoiler",
        Arguments.createMap().apply { putBoolean("isActive", isSpoiler) },
      )
      putMap(
        "link",
        Arguments.createMap().apply { putBoolean("isActive", isLink) },
      )
    }

  companion object {
    const val EVENT_NAME = "onChangeState"
  }
}
