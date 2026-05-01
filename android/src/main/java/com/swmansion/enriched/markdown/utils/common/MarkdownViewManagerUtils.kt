package com.swmansion.enriched.markdown.utils.common

import android.view.View
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.UIManagerHelper
import com.swmansion.enriched.markdown.events.ContextMenuItemPressEvent
import com.swmansion.enriched.markdown.events.LinkLongPressEvent
import com.swmansion.enriched.markdown.events.LinkPressEvent
import com.swmansion.enriched.markdown.events.TaskListItemPressEvent
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig

fun markdownEventTypeConstants(): MutableMap<String, Any> {
  val map = mutableMapOf<String, Any>()
  map[LinkPressEvent.EVENT_NAME] = mapOf("registrationName" to LinkPressEvent.EVENT_NAME)
  map[LinkLongPressEvent.EVENT_NAME] =
    mapOf("registrationName" to LinkLongPressEvent.EVENT_NAME)
  map[TaskListItemPressEvent.EVENT_NAME] =
    mapOf("registrationName" to TaskListItemPressEvent.EVENT_NAME)
  map[ContextMenuItemPressEvent.EVENT_NAME] =
    mapOf("registrationName" to ContextMenuItemPressEvent.EVENT_NAME)
  return map
}

fun emitLinkPress(
  view: View,
  url: String,
) {
  val context = view.context as com.facebook.react.bridge.ReactContext
  val surfaceId = UIManagerHelper.getSurfaceId(context)
  val eventDispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
  eventDispatcher?.dispatchEvent(LinkPressEvent(surfaceId, view.id, url))
}

fun emitLinkLongPress(
  view: View,
  url: String,
) {
  val context = view.context as com.facebook.react.bridge.ReactContext
  val surfaceId = UIManagerHelper.getSurfaceId(context)
  val eventDispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
  eventDispatcher?.dispatchEvent(LinkLongPressEvent(surfaceId, view.id, url))
}

fun emitTaskListItemPress(
  view: View,
  taskIndex: Int,
  checked: Boolean,
  itemText: String,
) {
  val context = view.context as com.facebook.react.bridge.ReactContext
  val surfaceId = UIManagerHelper.getSurfaceId(context)
  val eventDispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
  eventDispatcher?.dispatchEvent(
    TaskListItemPressEvent(surfaceId, view.id, taskIndex, checked, itemText),
  )
}

fun emitContextMenuItemPress(
  view: View,
  itemText: String,
  selectedText: String,
  selectionStart: Int,
  selectionEnd: Int,
) {
  val context = view.context as com.facebook.react.bridge.ReactContext
  val surfaceId = UIManagerHelper.getSurfaceId(context)
  val eventDispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
  eventDispatcher?.dispatchEvent(
    ContextMenuItemPressEvent(
      surfaceId,
      view.id,
      itemText,
      selectedText,
      selectionStart,
      selectionEnd,
    ),
  )
}

fun parseMd4cFlags(flags: ReadableMap?): Md4cFlags =
  Md4cFlags(
    underline = flags?.getBoolean("underline") ?: false,
    latexMath = FeatureFlags.IS_MATH_ENABLED && (flags?.getBoolean("latexMath") ?: true),
  )

fun parseContextMenuItems(value: ReadableArray?): List<String> =
  (0 until (value?.size() ?: 0)).mapNotNull { value?.getMap(it)?.getString("text") }

fun parseSelectionMenuConfig(value: ReadableMap?): SelectionMenuConfig {
  if (value == null) return SelectionMenuConfig()
  return SelectionMenuConfig(
    copyAsMarkdown = value.getBoolean("copyAsMarkdown"),
    copyImageUrl = value.getBoolean("copyImageUrl"),
  )
}
