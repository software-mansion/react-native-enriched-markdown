package com.swmansion.enriched.markdown.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class DataDetectorPressEvent(
  surfaceId: Int,
  viewId: Int,
  private val type: String,
  private val text: String,
  private val url: String,
  private val data: String,
) : Event<DataDetectorPressEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap {
    val eventData: WritableMap = Arguments.createMap()
    eventData.putString("type", type)
    eventData.putString("text", text)
    eventData.putString("url", url)
    eventData.putString("data", data)
    return eventData
  }

  companion object {
    const val EVENT_NAME: String = "onDataDetectorPress"
  }
}
