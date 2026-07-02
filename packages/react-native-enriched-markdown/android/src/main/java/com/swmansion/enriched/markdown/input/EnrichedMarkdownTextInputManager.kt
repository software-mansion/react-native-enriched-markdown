package com.swmansion.enriched.markdown.input

import android.content.Context
import android.graphics.Color
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ReactStylesDiffMap
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.EnrichedMarkdownTextInputManagerDelegate
import com.facebook.react.viewmanagers.EnrichedMarkdownTextInputManagerInterface
import com.facebook.yoga.YogaMeasureMode
import com.swmansion.enriched.markdown.input.autolink.LinkRegexConfig
import com.swmansion.enriched.markdown.input.events.OnCaretRectChangeEvent
import com.swmansion.enriched.markdown.input.events.OnChangeMarkdownEvent
import com.swmansion.enriched.markdown.input.events.OnChangeMentionEvent
import com.swmansion.enriched.markdown.input.events.OnChangeSelectionEvent
import com.swmansion.enriched.markdown.input.events.OnChangeStateEvent
import com.swmansion.enriched.markdown.input.events.OnChangeTextEvent
import com.swmansion.enriched.markdown.input.events.OnContextMenuItemPressEvent
import com.swmansion.enriched.markdown.input.events.OnEndMentionEvent
import com.swmansion.enriched.markdown.input.events.OnInputBlurEvent
import com.swmansion.enriched.markdown.input.events.OnInputFocusEvent
import com.swmansion.enriched.markdown.input.events.OnLinkDetectedEvent
import com.swmansion.enriched.markdown.input.events.OnRequestCaretRectResultEvent
import com.swmansion.enriched.markdown.input.events.OnRequestMarkdownResultEvent
import com.swmansion.enriched.markdown.input.events.OnStartMentionEvent
import com.swmansion.enriched.markdown.input.layout.InputMeasurementStore
import com.swmansion.enriched.markdown.input.model.StyleType
import com.swmansion.enriched.markdown.input.toolbar.FormatMenuConfig
import com.swmansion.enriched.markdown.input.toolbar.InputSelectionMenuConfig
import com.swmansion.enriched.markdown.utils.input.BorderPropsApplicator
import com.swmansion.enriched.markdown.utils.input.MarkdownStyleParser

@ReactModule(name = EnrichedMarkdownTextInputManager.NAME)
class EnrichedMarkdownTextInputManager :
  SimpleViewManager<EnrichedMarkdownTextInputScrollView>(),
  EnrichedMarkdownTextInputManagerInterface<EnrichedMarkdownTextInputScrollView> {
  private val delegate: ViewManagerDelegate<EnrichedMarkdownTextInputScrollView> =
    EnrichedMarkdownTextInputManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<EnrichedMarkdownTextInputScrollView> = delegate

  override fun getName(): String = NAME

  override fun createViewInstance(reactContext: ThemedReactContext): EnrichedMarkdownTextInputScrollView =
    EnrichedMarkdownTextInputScrollView(reactContext)

  override fun updateState(
    view: EnrichedMarkdownTextInputScrollView,
    props: ReactStylesDiffMap?,
    stateWrapper: StateWrapper?,
  ): Any? {
    // Route Fabric state to the editor so its auto-grow loop still drives the re-measure.
    view.input.stateWrapper = stateWrapper
    return super.updateState(view, props, stateWrapper)
  }

  override fun onAfterUpdateTransaction(view: EnrichedMarkdownTextInputScrollView) {
    super.onAfterUpdateTransaction(view)
    view.input.afterUpdateTransaction()
  }

  override fun onDropViewInstance(view: EnrichedMarkdownTextInputScrollView) {
    view.input.dismissActiveMention()
    super.onDropViewInstance(view)
    view.input.layoutManager.release()
  }

  override fun measure(
    context: Context,
    localData: ReadableMap?,
    props: ReadableMap?,
    state: ReadableMap?,
    width: Float,
    widthMode: YogaMeasureMode?,
    height: Float,
    heightMode: YogaMeasureMode?,
    attachmentsPositions: FloatArray?,
  ): Long {
    // The editor's content is measured by the container's tag (the editor shares it via setId).
    val id = localData?.getInt("viewTag")
    return InputMeasurementStore.getMeasureById(context, id, width, height, heightMode, props)
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    listOf(
      OnChangeTextEvent.EVENT_NAME,
      OnChangeMarkdownEvent.EVENT_NAME,
      OnChangeSelectionEvent.EVENT_NAME,
      OnChangeStateEvent.EVENT_NAME,
      OnRequestMarkdownResultEvent.EVENT_NAME,
      OnRequestCaretRectResultEvent.EVENT_NAME,
      OnCaretRectChangeEvent.EVENT_NAME,
      OnInputFocusEvent.EVENT_NAME,
      OnInputBlurEvent.EVENT_NAME,
      OnContextMenuItemPressEvent.EVENT_NAME,
      OnLinkDetectedEvent.EVENT_NAME,
      OnStartMentionEvent.EVENT_NAME,
      OnChangeMentionEvent.EVENT_NAME,
      OnEndMentionEvent.EVENT_NAME,
    ).associateWithTo(mutableMapOf()) { name -> mapOf("registrationName" to name) }

  // Props

  @ReactProp(name = "defaultValue")
  override fun setDefaultValue(
    view: EnrichedMarkdownTextInputScrollView?,
    value: String?,
  ) {
    val input = view?.input ?: return
    if (value != null && input.text?.isEmpty() == true) {
      input.setValueFromJS(value)
    }
  }

  @ReactProp(name = "placeholder")
  override fun setPlaceholder(
    view: EnrichedMarkdownTextInputScrollView?,
    value: String?,
  ) {
    view?.input?.hint = value
  }

  @ReactProp(name = "placeholderTextColor", customType = "Color")
  override fun setPlaceholderTextColor(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Int?,
  ) {
    view?.input?.setHintTextColor(value ?: Color.GRAY)
  }

  @ReactProp(name = "editable", defaultBoolean = true)
  override fun setEditable(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Boolean,
  ) {
    view?.input?.isEnabled = value
  }

  @ReactProp(name = "autoFocus", defaultBoolean = false)
  override fun setAutoFocus(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Boolean,
  ) {
    view?.input?.autoFocusRequested = value
  }

  @ReactProp(name = "scrollEnabled", defaultBoolean = true)
  override fun setScrollEnabled(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Boolean,
  ) {
    // The editor never scrolls itself; the container does. Gate the container's scrolling and its
    // scrollbar so scrollEnabled={false} truly disables scrolling (parity with iOS).
    view?.scrollingEnabled = value
    view?.isVerticalScrollBarEnabled = value
  }

  @ReactProp(name = "contentInset")
  override fun setContentInset(
    view: EnrichedMarkdownTextInputScrollView?,
    value: ReadableMap?,
  ) {
    view?.setContentInsetFromProps(value)
  }

  @ReactProp(name = "autoCapitalize")
  override fun setAutoCapitalize(
    view: EnrichedMarkdownTextInputScrollView?,
    value: String?,
  ) {
    view?.input?.setAutoCapitalize(value)
  }

  @ReactProp(name = "multiline", defaultBoolean = true)
  override fun setMultiline(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Boolean,
  ) {
    view?.input?.isSingleLine = !value
  }

  @ReactProp(name = "cursorColor", customType = "Color")
  override fun setCursorColor(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Int?,
  ) {
    view?.input?.setCursorColorFromProps(value)
  }

  @ReactProp(name = "selectionColor", customType = "Color")
  override fun setSelectionColor(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Int?,
  ) {
    if (value != null) {
      view?.input?.highlightColor = value
    }
  }

  @ReactProp(name = "markdownStyle")
  override fun setMarkdownStyle(
    view: EnrichedMarkdownTextInputScrollView?,
    value: ReadableMap?,
  ) {
    val input = view?.input ?: return
    if (value == null) return

    val style = MarkdownStyleParser.parse(value)
    input.setAutoLinkStyle(style)
    val changed = input.formatter.updateStyle(style)
    if (changed) {
      input.applyFormatting()
    }
  }

  @ReactProp(name = "color", customType = "Color")
  override fun setColor(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Int?,
  ) {
    view?.input?.setColorFromProps(value)
  }

  @ReactProp(name = "fontSize", defaultFloat = 16f)
  override fun setFontSize(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Float,
  ) {
    view?.input?.setFontSizeFromProps(value)
  }

  @ReactProp(name = "lineHeight", defaultFloat = 0f)
  override fun setLineHeight(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Float,
  ) {
    val input = view?.input ?: return
    if (value > 0) {
      input.setLineSpacing(value - input.textSize, 1f)
    }
  }

  @ReactProp(name = "fontFamily")
  override fun setFontFamily(
    view: EnrichedMarkdownTextInputScrollView?,
    value: String?,
  ) {
    view?.input?.setFontFamily(value)
  }

  @ReactProp(name = "fontWeight")
  override fun setFontWeight(
    view: EnrichedMarkdownTextInputScrollView?,
    value: String?,
  ) {
    view?.input?.setFontWeight(value)
  }

  @ReactProp(name = "isOnChangeMarkdownSet", defaultBoolean = false)
  override fun setIsOnChangeMarkdownSet(
    view: EnrichedMarkdownTextInputScrollView?,
    value: Boolean,
  ) {
    view?.input?.emitMarkdown = value
  }

  @ReactProp(name = "contextMenuItems")
  override fun setContextMenuItems(
    view: EnrichedMarkdownTextInputScrollView?,
    value: ReadableArray?,
  ) {
    val input = view?.input ?: return
    val items = (0 until (value?.size() ?: 0)).mapNotNull { value?.getMap(it)?.getString("text") }
    input.setContextMenuItems(items)
  }

  @ReactProp(name = "selectionMenuConfig")
  override fun setSelectionMenuConfig(
    view: EnrichedMarkdownTextInputScrollView?,
    value: ReadableMap?,
  ) {
    val input = view?.input ?: return
    input.contextMenu.selectionMenuConfig =
      if (value == null) {
        InputSelectionMenuConfig()
      } else {
        InputSelectionMenuConfig(
          format = value.getBoolean("format"),
          formatLabel = value.getString("formatLabel") ?: "",
          copyAsMarkdown = value.getBoolean("copyAsMarkdown"),
          copyAsMarkdownLabel = value.getString("copyAsMarkdownLabel") ?: "",
        )
      }
  }

  @ReactProp(name = "formatMenuConfig")
  override fun setFormatMenuConfig(
    view: EnrichedMarkdownTextInputScrollView?,
    value: ReadableMap?,
  ) {
    val input = view?.input ?: return
    input.contextMenu.formatMenuConfig =
      if (value == null) {
        FormatMenuConfig()
      } else {
        FormatMenuConfig(
          bold = value.getBoolean("bold"),
          boldLabel = value.getString("boldLabel") ?: "",
          italic = value.getBoolean("italic"),
          italicLabel = value.getString("italicLabel") ?: "",
          underline = value.getBoolean("underline"),
          underlineLabel = value.getString("underlineLabel") ?: "",
          strikethrough = value.getBoolean("strikethrough"),
          strikethroughLabel = value.getString("strikethroughLabel") ?: "",
          spoiler = value.getBoolean("spoiler"),
          spoilerLabel = value.getString("spoilerLabel") ?: "",
          link = value.getBoolean("link"),
          linkLabel = value.getString("linkLabel") ?: "",
        )
      }
  }

  @ReactProp(name = "linkRegex")
  override fun setLinkRegex(
    view: EnrichedMarkdownTextInputScrollView?,
    value: ReadableMap?,
  ) {
    val input = view?.input ?: return
    val config =
      if (value != null) {
        LinkRegexConfig(
          pattern = value.getString("pattern") ?: "",
          caseInsensitive = value.getBoolean("caseInsensitive"),
          dotAll = value.getBoolean("dotAll"),
          isDisabled = value.getBoolean("isDisabled"),
          isDefault = value.getBoolean("isDefault"),
        )
      } else {
        LinkRegexConfig("", caseInsensitive = false, dotAll = false, isDisabled = false, isDefault = true)
      }
    input.setLinkRegex(config)
  }

  @ReactProp(name = "mentionIndicators")
  override fun setMentionIndicators(
    view: EnrichedMarkdownTextInputScrollView?,
    value: ReadableArray?,
  ) {
    val indicators =
      (0 until (value?.size() ?: 0))
        .mapNotNull { value?.getString(it) }
        .filter { it.isNotEmpty() }
    view?.input?.setMentionIndicators(indicators)
  }

  @ReactProp(name = "writingDirection")
  override fun setWritingDirection(
    view: EnrichedMarkdownTextInputScrollView?,
    value: String?,
  ) {
    // No-op on Android — EditText resolves direction per paragraph via
    // TEXT_DIRECTION_FIRST_STRONG (the platform default).
  }

  override fun updateProperties(
    view: EnrichedMarkdownTextInputScrollView,
    props: ReactStylesDiffMap,
  ) {
    // Apply border/background to the container (the visible frame), not the scrolling editor.
    BorderPropsApplicator.apply(view, props)
    super.updateProperties(view, props)
  }

  override fun setPadding(
    view: EnrichedMarkdownTextInputScrollView?,
    left: Int,
    top: Int,
    right: Int,
    bottom: Int,
  ) {
    super.setPadding(view, left, top, right, bottom)
    // Route React `padding` through the same path as contentInset so the auto-grow measure accounts
    // for it (plain setPadding would leave the measured height short by the vertical padding).
    view?.input?.setReactPadding(left, top, right, bottom)
  }

  // Commands

  override fun focus(view: EnrichedMarkdownTextInputScrollView?) {
    view?.input?.requestFocusProgrammatically()
  }

  override fun blur(view: EnrichedMarkdownTextInputScrollView?) {
    view?.input?.clearFocus()
  }

  override fun setValue(
    view: EnrichedMarkdownTextInputScrollView?,
    markdown: String?,
  ) {
    if (markdown != null) {
      view?.input?.setValueFromJS(markdown)
    }
  }

  override fun setSelection(
    view: EnrichedMarkdownTextInputScrollView?,
    start: Int,
    end: Int,
  ) {
    val input = view?.input ?: return
    val length = input.text?.length ?: 0
    val clampedStart = start.coerceIn(0, length)
    val clampedEnd = end.coerceIn(0, length)
    input.setSelection(clampedStart, clampedEnd)
  }

  override fun toggleBold(view: EnrichedMarkdownTextInputScrollView?) {
    view?.input?.toggleInlineStyle(StyleType.BOLD)
  }

  override fun toggleItalic(view: EnrichedMarkdownTextInputScrollView?) {
    view?.input?.toggleInlineStyle(StyleType.ITALIC)
  }

  override fun toggleUnderline(view: EnrichedMarkdownTextInputScrollView?) {
    view?.input?.toggleInlineStyle(StyleType.UNDERLINE)
  }

  override fun toggleStrikethrough(view: EnrichedMarkdownTextInputScrollView?) {
    view?.input?.toggleInlineStyle(StyleType.STRIKETHROUGH)
  }

  override fun toggleSpoiler(view: EnrichedMarkdownTextInputScrollView?) {
    view?.input?.toggleInlineStyle(StyleType.SPOILER)
  }

  override fun setLink(
    view: EnrichedMarkdownTextInputScrollView?,
    url: String?,
  ) {
    if (url != null) {
      view?.input?.setLinkForSelection(url)
    }
  }

  override fun insertLink(
    view: EnrichedMarkdownTextInputScrollView?,
    text: String?,
    url: String?,
  ) {
    if (url != null) {
      view?.input?.insertLinkAtCursor(text ?: url, url)
    }
  }

  override fun insertMention(
    view: EnrichedMarkdownTextInputScrollView?,
    displayText: String?,
    url: String?,
  ) {
    if (displayText != null && url != null) {
      view?.input?.insertMention(displayText, url)
    }
  }

  override fun startMention(
    view: EnrichedMarkdownTextInputScrollView?,
    indicator: String?,
  ) {
    if (indicator != null) {
      view?.input?.startMention(indicator)
    }
  }

  override fun removeLink(view: EnrichedMarkdownTextInputScrollView?) {
    view?.input?.removeLinkAtCursor()
  }

  override fun copyToClipboard(view: EnrichedMarkdownTextInputView?) {
    view?.copyToClipboard()
  }

  override fun requestMarkdown(
    view: EnrichedMarkdownTextInputScrollView?,
    requestId: Int,
  ) {
    view?.input?.eventEmitter?.emitRequestMarkdownResult(requestId)
  }

  override fun requestCaretRect(
    view: EnrichedMarkdownTextInputScrollView?,
    requestId: Int,
  ) {
    view?.input?.eventEmitter?.emitRequestCaretRectResult(requestId)
  }

  companion object {
    const val NAME = "EnrichedMarkdownTextInput"
  }
}
