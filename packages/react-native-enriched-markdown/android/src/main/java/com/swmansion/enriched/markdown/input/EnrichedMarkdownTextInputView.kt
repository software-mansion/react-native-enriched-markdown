package com.swmansion.enriched.markdown.input

import android.content.Context
import android.graphics.BlendMode
import android.graphics.BlendModeColorFilter
import android.graphics.Color
import android.os.Build
import android.text.Editable
import android.text.InputType
import android.text.Spanned
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View.OnFocusChangeListener
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.view.inputmethod.InputMethodManager
import androidx.appcompat.widget.AppCompatEditText
import com.facebook.react.common.ReactConstants
import com.facebook.react.uimanager.BackgroundStyleApplicator
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.views.text.ReactTypefaceUtils
import com.swmansion.enriched.markdown.input.autolink.AutoLinkDetector
import com.swmansion.enriched.markdown.input.autolink.LinkRegexConfig
import com.swmansion.enriched.markdown.input.detection.DetectorPipeline
import com.swmansion.enriched.markdown.input.detection.WordsUtils
import com.swmansion.enriched.markdown.input.editing.InputConnectionWrapper
import com.swmansion.enriched.markdown.input.editing.MarkdownEditableFactory
import com.swmansion.enriched.markdown.input.editing.MarkdownTextWatcher
import com.swmansion.enriched.markdown.input.formatting.FormattingStore
import com.swmansion.enriched.markdown.input.formatting.InputFormatter
import com.swmansion.enriched.markdown.input.formatting.InputParser
import com.swmansion.enriched.markdown.input.layout.InputEventEmitter
import com.swmansion.enriched.markdown.input.layout.InputLayoutManager
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.InputFormatterStyle
import com.swmansion.enriched.markdown.input.model.MAX_LIST_DEPTH
import com.swmansion.enriched.markdown.input.model.StyleType
import com.swmansion.enriched.markdown.input.toolbar.InputContextMenu
import com.swmansion.enriched.markdown.spans.InputBulletSpan
import com.swmansion.enriched.markdown.spans.InputListItemSpacingSpan
import com.swmansion.enriched.markdown.utils.input.AutoCapitalizeUtils
import kotlin.math.ceil

private fun Char.isLineBreak(): Boolean = this == '\n' || this == '\r' || this == '\u0085' || this == '\u2028' || this == '\u2029'

class EnrichedMarkdownTextInputView(
  context: Context,
) : AppCompatEditText(context) {
  private var isComponentReady = false

  val formattingStore = FormattingStore()
  val formatter = InputFormatter()
  val pendingStyles = mutableSetOf<StyleType>()
  val pendingStyleRemovals = mutableSetOf<StyleType>()

  // List kind/depth the next typed character should adopt when the cursor sits on
  // an empty line (no character holds the block span yet).
  private var pendingBlockType: BlockType = BlockType.PARAGRAPH
  private var pendingListDepth: Int = 0

  // Set when a block is toggled onto an empty line so the selection-change it
  // triggers doesn't immediately clear the pending kind (which is the only thing
  // keeping the marker visible until a character is typed).
  private var keepPendingBlockOnEmptyLine = false

  // Extra vertical spacing (px) added above each list item; 0 = none.
  private var listItemSpacingPx = 0f

  // Guards re-entrancy while the empty-list-line ZWSP anchor is being managed
  // (its insert/delete + setSelection would otherwise loop back through the
  // text/selection callbacks).
  private var isManagingZwsp = false

  // The consumer-set placeholder. Hidden while a bullet is drawn on the empty
  // editor so the marker doesn't overlap it (mirrors the iOS placeholder hide).
  private var userHint: CharSequence? = null

  fun setUserHint(value: CharSequence?) {
    userHint = value
    syncHintVisibility()
  }

  private fun syncHintVisibility() {
    val hideForBullet = text.isNullOrEmpty() && pendingBlockType == BlockType.UNORDERED_LIST_ITEM
    val target: CharSequence? = if (hideForBullet) "" else userHint
    if (hint != target) super.setHint(target)
    syncEmptyListZwsp()
  }

  /**
   * On an empty list line the caret would render *before* the bullet: Android
   * doesn't apply a [LeadingMarginSpan]'s indent to the caret on an empty
   * paragraph. So anchor the line with a zero-width space carrying the bullet
   * span — the marker draws and the caret sits after it like a normal item. The
   * ZWSP is removed once the line gains real content or the caret leaves, and is
   * stripped on serialization, so it never reaches the Markdown output.
   */
  private fun syncEmptyListZwsp() {
    if (isManagingZwsp) return
    val editable = text ?: return
    isManagingZwsp = true
    try {
      val cursorLineStart = lineBounds(selectionStart).first
      val onEmptyListLine =
        selectionStart == selectionEnd &&
          blockTypeAtCursor() == BlockType.UNORDERED_LIST_ITEM &&
          run {
            val (ls, le) = lineBounds(selectionStart)
            val content = editable.subSequence(ls, le).toString()
            content.isEmpty() || content == "\u200B"
          }

      // Drop every ZWSP that isn't the anchor on the current empty list line
      // (covers leaving the line and typing real content onto it).
      var i = editable.length - 1
      while (i >= 0) {
        if (editable[i] == '\u200B') {
          val keep = onEmptyListLine && lineBounds(i).first == cursorLineStart
          if (!keep) runAsATransaction { editable.delete(i, i + 1) }
        }
        i--
      }

      if (!onEmptyListLine) return

      val (ls, le) = lineBounds(selectionStart)
      if (le == ls) {
        runAsATransaction {
          editable.insert(ls, "\u200B")
          editable.setSpan(
            InputBulletSpan(listDepthAtCursor(), displayDensity),
            ls,
            ls + 1,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
          )
          applyListItemSpacingSpan(editable, ls, ls + 1)
        }
        setSelection(ls + 1)
      } else {
        if (bulletSpansIn(editable, ls, le).isEmpty()) {
          editable.setSpan(
            InputBulletSpan(listDepthAtCursor(), displayDensity),
            ls,
            le,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
          )
          applyListItemSpacingSpan(editable, ls, le)
        }
        if (selectionStart != le) setSelection(le)
      }
    } finally {
      isManagingZwsp = false
    }
  }

  var isDuringTransaction = false
    private set

  var blockEmitting = false

  private var isTextChanging = false
  var isProcessingTextChange = false
    private set
  private var didTextChangeRecently = false
  private var lastProcessedText: String = ""
  private var preEditSelectionStart = 0
  private var preEditSelectionEnd = 0

  var emitMarkdown = false
  var autoFocusRequested = false
  var stateWrapper: StateWrapper? = null
  val layoutManager = InputLayoutManager(this)
  private var pendingAutoFocusKeyboard = false

  private var typefaceDirty = false
  private var fontFamilyValue: String? = null
  private var fontWeightValue: Int = ReactConstants.UNSET

  val contextMenu = InputContextMenu(this)
  val eventEmitter = InputEventEmitter(this)
  private val autoLinkDetector = AutoLinkDetector(formattingStore)
  private val detectorPipeline = DetectorPipeline()

  private var textWatcher: MarkdownTextWatcher? = null
  private var inputMethodManager: InputMethodManager? = null
  private var detectScrollMovement = false
  var scrollEnabled: Boolean = true

  private var mentionIndicators: LinkedHashSet<String> = linkedSetOf()
  private var activeMentionIndicator: String? = null
  private var activeMentionStart = -1
  private var activeMentionEnd = -1
  private var activeMentionText = ""

  init {
    setupDetectorPipeline()
    prepareComponent()
    isComponentReady = true
  }

  private fun setupDetectorPipeline() {
    autoLinkDetector.onLinkDetected = { text, url, start, end ->
      eventEmitter.emitLinkDetected(text, url, start, end)
    }
    detectorPipeline.addDetector(autoLinkDetector)
  }

  private fun prepareComponent() {
    isSingleLine = false
    isHorizontalScrollBarEnabled = false
    isVerticalScrollBarEnabled = true
    inputType = InputType.TYPE_CLASS_TEXT or
      InputType.TYPE_TEXT_FLAG_MULTI_LINE or
      InputType.TYPE_TEXT_FLAG_CAP_SENTENCES or
      InputType.TYPE_TEXT_FLAG_AUTO_CORRECT
    gravity = Gravity.TOP or Gravity.START

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      breakStrategy = android.graphics.text.LineBreaker.BREAK_STRATEGY_HIGH_QUALITY
    }

    setEditableFactory(MarkdownEditableFactory(this))
    setPadding(0, 0, 0, 0)
    background = null
    BackgroundStyleApplicator.setBackgroundColor(this, Color.TRANSPARENT)
    contextMenu.install()

    inputMethodManager = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager

    onFocusChangeListener =
      OnFocusChangeListener { _, hasFocus ->
        if (hasFocus) {
          eventEmitter.emitFocus()
        } else {
          eventEmitter.emitBlur()
        }
      }
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    runAsATransaction { super.setTextIsSelectable(true) }
  }

  override fun onWindowFocusChanged(hasWindowFocus: Boolean) {
    super.onWindowFocusChanged(hasWindowFocus)
    // The autofocus keyboard request may run before the window has IME focus (e.g. while a modal is
    // still presenting), where showSoftInput() is dropped.
    showAutoFocusKeyboardIfPending()
  }

  override fun clearFocus() {
    super.clearFocus()
    inputMethodManager?.hideSoftInputFromWindow(windowToken, 0)
  }

  override fun onCreateInputConnection(outAttrs: EditorInfo): InputConnection? {
    val base = super.onCreateInputConnection(outAttrs) ?: return null
    return InputConnectionWrapper(base, this)
  }

  override fun onKeyDown(
    keyCode: Int,
    event: KeyEvent?,
  ): Boolean {
    if (keyCode == KeyEvent.KEYCODE_DEL && deleteLinkBeforeCursor()) {
      return true
    }
    if (handleListKey(keyCode, event)) {
      return true
    }
    return super.onKeyDown(keyCode, event)
  }

  // Prevents TextView from deferring its internal layout when a Fabric
  // state-update (height change) triggers requestLayout(). Without this
  // override the deferred relayout causes a visible flicker of styled spans.
  // See: ReactEditText in React Native core.
  override fun isLayoutRequested(): Boolean = false

  override fun onTouchEvent(ev: MotionEvent): Boolean {
    when (ev.action) {
      MotionEvent.ACTION_DOWN -> {
        detectScrollMovement = true
        parent?.requestDisallowInterceptTouchEvent(true)
      }

      MotionEvent.ACTION_MOVE -> {
        if (detectScrollMovement) {
          if (!canScrollVertically(-1) && !canScrollVertically(1) &&
            !canScrollHorizontally(-1) && !canScrollHorizontally(1)
          ) {
            parent?.requestDisallowInterceptTouchEvent(false)
          }
          detectScrollMovement = false
        }
      }
    }
    return super.onTouchEvent(ev)
  }

  override fun performClick(): Boolean = super.performClick()

  // In auto-grow mode (scrollEnabled=false) TextView's internal bringPointIntoView
  // scrolls content before Fabric has resized the view, causing a visible flicker.
  override fun scrollTo(
    x: Int,
    y: Int,
  ) {
    if (!scrollEnabled) return
    super.scrollTo(x, y)
  }

  override fun canScrollVertically(direction: Int): Boolean = scrollEnabled && super.canScrollVertically(direction)

  override fun canScrollHorizontally(direction: Int): Boolean = scrollEnabled && super.canScrollHorizontally(direction)

  fun attachTextWatcher(editable: Editable) {
    if (textWatcher != null) {
      editable.removeSpan(textWatcher)
    }
    textWatcher = MarkdownTextWatcher(this)
    addTextChangedListener(textWatcher)
  }

  fun runAsATransaction(block: () -> Unit) {
    try {
      isDuringTransaction = true
      block()
    } finally {
      isDuringTransaction = false
    }
  }

  fun onBeforeTextChanged() {
    if (isProcessingTextChange) return
    isTextChanging = true
    preEditSelectionStart = selectionStart
    preEditSelectionEnd = selectionEnd
  }

  fun onAfterTextChanged(
    editStart: Int,
    deletedLength: Int,
    insertedLength: Int,
  ) {
    if (isProcessingTextChange) return

    val currentText = text?.toString() ?: ""
    if (currentText == lastProcessedText) return

    isProcessingTextChange = true
    try {
      formattingStore.adjustForEdit(editStart, deletedLength, insertedLength)
      applyPendingStyles(editStart, insertedLength)

      val insertedHasGlyph =
        insertedLength > 0 &&
          run {
            val t = text
            val end = editStart + insertedLength
            t != null && end <= t.length && (editStart until end).any { !t[it].isLineBreak() }
          }
      normalizeBulletSpans(insertedHasGlyph, editStart, insertedLength)

      applyFormatting()

      val editable = text
      if (editable != null) {
        detectorPipeline.processTextChange(editable, currentText, editStart, insertedLength)
      }

      forceScrollToSelection()
      eventEmitter.emitChangeText()
      if (emitMarkdown) eventEmitter.emitChangeMarkdown()
      updateActiveMention()
      eventEmitter.emitCaretRectChangeIfNeeded()
      isTextChanging = false
      didTextChangeRecently = true
      lastProcessedText = currentText
      syncHintVisibility()
    } finally {
      isProcessingTextChange = false
    }
  }

  override fun onSelectionChanged(
    selStart: Int,
    selEnd: Int,
  ) {
    super.onSelectionChanged(selStart, selEnd)
    if (!isComponentReady || isDuringTransaction) return

    if (!isTextChanging) {
      if (didTextChangeRecently) {
        didTextChangeRecently = false
      } else {
        pendingStyles.clear()
        pendingStyleRemovals.clear()
        // List kind carries via the span on non-empty lines; clear the pending
        // kind so it never leaks onto a different (empty) line — unless a list was
        // just toggled onto this still-empty line, where pending is the only marker.
        val (cls, cle) = lineBounds(selStart)
        if (keepPendingBlockOnEmptyLine && cle == cls) {
          keepPendingBlockOnEmptyLine = false
        } else {
          keepPendingBlockOnEmptyLine = false
          pendingBlockType = BlockType.PARAGRAPH
          pendingListDepth = 0
        }
      }
    }

    eventEmitter.emitSelection(selStart, selEnd)
    updateActiveMention()
    eventEmitter.emitState()
    eventEmitter.emitCaretRectChangeIfNeeded()
    syncHintVisibility()
  }

  private fun applyPendingStyles(
    editStart: Int,
    insertedLength: Int,
  ) {
    if (insertedLength == 0) return
    if (pendingStyles.isEmpty() && pendingStyleRemovals.isEmpty()) return

    val rangeStart = if (preEditSelectionStart != preEditSelectionEnd) preEditSelectionStart else editStart
    val rangeEnd = rangeStart + insertedLength

    // Skip applying pending styles when the insertion is only line breaks —
    // a phantom range over a bare newline corrupts isStyleActive() at the boundary.
    val currentText = text
    val insertedHasGlyphContent =
      currentText != null &&
        rangeEnd <= currentText.length &&
        (rangeStart until rangeEnd).any { !currentText[it].isLineBreak() }

    if (insertedHasGlyphContent) {
      for (style in pendingStyles) {
        formattingStore.addRange(FormattingRange(style, rangeStart, rangeEnd))
      }
    }

    for (style in pendingStyleRemovals) {
      formattingStore.removeType(style, rangeStart, rangeEnd)
    }
  }

  fun applyFormatting() {
    val editable = text ?: return
    formatter.applyFormatting(editable, formattingStore.allRanges)
  }

  private fun applyFormattingAndEmit() {
    applyFormatting()
    forceScrollToSelection()
    if (emitMarkdown) eventEmitter.emitChangeMarkdown()
    eventEmitter.emitState()
  }

  private fun forceScrollToSelection() {
    val textLayout = layout ?: return
    val cursorOffset = selectionStart
    if (cursorOffset <= 0) return

    val selectedLineIndex = textLayout.getLineForOffset(cursorOffset)
    val selectedLineTop = textLayout.getLineTop(selectedLineIndex)
    val selectedLineBottom = textLayout.getLineBottom(selectedLineIndex)
    val visibleTextHeight = height - paddingTop - paddingBottom
    if (visibleTextHeight <= 0) return

    val visibleTop = scrollY
    val visibleBottom = scrollY + visibleTextHeight
    var targetScrollY = scrollY

    if (selectedLineTop < visibleTop) {
      targetScrollY = selectedLineTop
    } else if (selectedLineBottom > visibleBottom) {
      targetScrollY = selectedLineBottom - visibleTextHeight
    }

    val maxScrollY = (textLayout.height - visibleTextHeight).coerceAtLeast(0)
    targetScrollY = targetScrollY.coerceIn(0, maxScrollY)
    scrollTo(scrollX, targetScrollY)
  }

  fun toggleInlineStyle(styleType: StyleType) {
    val handler = formatter.handlers[styleType] ?: return
    val mergingConfig = handler.mergingConfig

    val selStart = selectionStart
    val selEnd = selectionEnd

    // Check blocking rules: if any blocking style is active, refuse to toggle on.
    if (mergingConfig.blockingStyles.isNotEmpty()) {
      val isCurrentlyActive = formattingStore.isStyleActive(styleType, selStart)
      if (!isCurrentlyActive) {
        for (blocker in mergingConfig.blockingStyles) {
          if (formattingStore.isStyleActive(blocker, selStart)) {
            return
          }
        }
      }
    }

    if (selStart == selEnd) {
      if (pendingStyleRemovals.contains(styleType)) {
        pendingStyleRemovals.remove(styleType)
        pendingStyles.add(styleType)
      } else if (pendingStyles.contains(styleType)) {
        pendingStyles.remove(styleType)
        pendingStyleRemovals.add(styleType)
      } else if (formattingStore.isStyleActive(styleType, selStart)) {
        pendingStyleRemovals.add(styleType)
      } else {
        pendingStyles.add(styleType)
      }
      eventEmitter.emitState()
    } else {
      val isActive = formattingStore.isStyleActive(styleType, selStart)
      if (isActive) {
        formattingStore.removeType(styleType, selStart, selEnd)
      } else {
        // Remove conflicting styles from the range before applying.
        for (conflict in mergingConfig.conflictingStyles) {
          formattingStore.removeType(conflict, selStart, selEnd)
        }
        formattingStore.addRange(FormattingRange(styleType, selStart, selEnd))
      }
      applyFormattingAndEmit()
    }
  }

  // region Block styles

  private val displayDensity: Float get() = resources.displayMetrics.density

  /** Start/end (exclusive) offsets of the line's content containing [offset], excluding newlines. */
  private fun lineBounds(offset: Int): Pair<Int, Int> {
    val s = text ?: return 0 to 0
    val len = s.length
    val pos = offset.coerceIn(0, len)
    var start = pos
    while (start > 0 && s[start - 1] != '\n') start--
    var end = pos
    while (end < len && s[end] != '\n') end++
    return start to end
  }

  private fun bulletSpansIn(
    editable: Editable,
    start: Int,
    end: Int,
  ): Array<InputBulletSpan> = editable.getSpans(start, end, InputBulletSpan::class.java)

  private fun removeBulletSpans(
    editable: Editable,
    start: Int,
    end: Int,
  ) {
    for (span in bulletSpansIn(editable, start, end)) editable.removeSpan(span)
    for (span in editable.getSpans(start, end, InputListItemSpacingSpan::class.java)) editable.removeSpan(span)
  }

  /** Block kind of the cursor's line, falling back to the pending kind for empty lines. */
  fun blockTypeAtCursor(): BlockType {
    val editable = text ?: return pendingBlockType
    if (editable.isEmpty()) return pendingBlockType
    val (ls, le) = lineBounds(selectionStart)
    if (le <= ls) return pendingBlockType
    return bulletSpansIn(editable, ls, le).firstOrNull()?.blockType ?: BlockType.PARAGRAPH
  }

  /** List depth of the cursor's line, or the pending depth for an empty line. */
  fun listDepthAtCursor(): Int {
    val editable = text ?: return pendingListDepth
    if (editable.isEmpty()) return pendingListDepth
    val (ls, le) = lineBounds(selectionStart)
    if (le <= ls) return pendingListDepth
    return bulletSpansIn(editable, ls, le).firstOrNull()?.depth ?: 0
  }

  /** List ranges currently stored as spans, in text coordinates. */
  fun currentBlockRanges(): List<BlockRange> {
    val editable = text ?: return emptyList()
    return editable
      .getSpans(0, editable.length, InputBulletSpan::class.java)
      .mapNotNull { span ->
        val start = editable.getSpanStart(span)
        val end = editable.getSpanEnd(span)
        if (end > start) BlockRange(BlockType.UNORDERED_LIST_ITEM, start, end, span.depth) else null
      }
  }

  private fun applyBulletSpan(
    editable: Editable,
    start: Int,
    end: Int,
    depth: Int,
  ) {
    if (end <= start) return
    removeBulletSpans(editable, start, end)
    editable.setSpan(InputBulletSpan(depth, displayDensity), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    applyListItemSpacingSpan(editable, start, end)
  }

  /**
   * Adds the configured leading spacing above a list item. Applied to only the
   * first character so it affects just the item's first visual line, not wrapped
   * continuations. No-op when spacing is 0.
   */
  private fun applyListItemSpacingSpan(
    editable: Editable,
    start: Int,
    end: Int,
  ) {
    if (listItemSpacingPx <= 0f || end <= start) return
    editable.setSpan(
      InputListItemSpacingSpan(listItemSpacingPx.toInt()),
      start,
      (start + 1).coerceAtMost(end),
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
  }

  fun toggleUnorderedList() {
    val editable = text ?: return
    val turningOff = blockTypeAtCursor() == BlockType.UNORDERED_LIST_ITEM
    val selEnd = selectionEnd
    var cursor = lineBounds(selectionStart).first
    while (cursor <= editable.length) {
      val (ls, le) = lineBounds(cursor)
      if (turningOff) {
        removeBulletSpans(editable, ls, le)
      } else if (le > ls) {
        applyBulletSpan(editable, ls, le, 0)
      }
      if (le >= selEnd) break
      cursor = le + 1
    }
    pendingBlockType = if (turningOff) BlockType.PARAGRAPH else BlockType.UNORDERED_LIST_ITEM
    pendingListDepth = 0
    keepPendingBlockOnEmptyLine = !turningOff
    applyFormatting()
    forceScrollToSelection()
    invalidate() // redraw the empty-line marker (no span change to trigger it)
    syncHintVisibility()
    if (emitMarkdown) eventEmitter.emitChangeMarkdown()
    eventEmitter.emitState()
  }

  fun indentList() = changeListDepthBy(1)

  fun outdentList() = changeListDepthBy(-1)

  private fun changeListDepthBy(delta: Int) {
    if (blockTypeAtCursor() != BlockType.UNORDERED_LIST_ITEM) return
    val editable = text ?: return
    val selEnd = selectionEnd
    var cursor = lineBounds(selectionStart).first
    while (cursor <= editable.length) {
      val (ls, le) = lineBounds(cursor)
      val span = bulletSpansIn(editable, ls, le).firstOrNull()
      if (span != null && le > ls) {
        val newDepth = (span.depth + delta).coerceIn(0, MAX_LIST_DEPTH)
        applyBulletSpan(editable, ls, le, newDepth)
      }
      if (le >= selEnd) break
      cursor = le + 1
    }
    pendingListDepth = (listDepthAtCursor() + delta).coerceIn(0, MAX_LIST_DEPTH)
    keepPendingBlockOnEmptyLine = true
    applyFormatting()
    forceScrollToSelection()
    invalidate() // redraw the empty-line marker at the new depth
    if (emitMarkdown) eventEmitter.emitChangeMarkdown()
    eventEmitter.emitState()
  }

  /** Writes parsed list ranges into the text as spans. */
  private fun applyBlockRanges(blockRanges: List<BlockRange>) {
    val editable = text ?: return
    removeBulletSpans(editable, 0, editable.length)
    for (range in blockRanges) {
      if (range.type != BlockType.UNORDERED_LIST_ITEM) continue
      val start = range.start.coerceIn(0, editable.length)
      val end = range.end.coerceIn(start, editable.length)
      if (end > start) {
        editable.setSpan(InputBulletSpan(range.depth, displayDensity), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        applyListItemSpacingSpan(editable, start, end)
      }
    }
  }

  /**
   * Keeps bullet spans well-formed after an edit: seeds a span for the first
   * character typed on a freshly-toggled empty line, continues the list onto a
   * new line created by Enter (exiting on an empty item), and re-clamps every
   * bullet span to its line's content so typing extends it without crossing a
   * newline.
   */
  private fun normalizeBulletSpans(
    insertedHasGlyph: Boolean,
    editStart: Int,
    insertedLength: Int,
  ) {
    val editable = text ?: return

    if (insertedHasGlyph) {
      if (pendingBlockType == BlockType.UNORDERED_LIST_ITEM) {
        val (ls, le) = lineBounds(selectionStart)
        if (le > ls && bulletSpansIn(editable, ls, le).isEmpty()) {
          editable.setSpan(
            InputBulletSpan(pendingListDepth, displayDensity),
            ls,
            le,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
          )
          applyListItemSpacingSpan(editable, ls, le)
        }
      }
    } else if (insertedLength > 0) {
      // A newline was inserted: continue the list, or exit on an empty item.
      val prevLineEnd = editStart
      var prevLineStart = prevLineEnd
      while (prevLineStart > 0 && editable[prevLineStart - 1] != '\n') prevLineStart--
      val prevContentLength = (prevLineEnd - prevLineStart).coerceAtLeast(0)

      var prevIsList = false
      var prevDepth = 0
      if (prevContentLength > 0) {
        val span = bulletSpansIn(editable, prevLineStart, prevLineEnd).firstOrNull()
        if (span != null) {
          prevIsList = true
          prevDepth = span.depth
        }
      } else {
        prevIsList = pendingBlockType == BlockType.UNORDERED_LIST_ITEM
        prevDepth = pendingListDepth
      }

      if (prevIsList && prevContentLength > 0) {
        pendingBlockType = BlockType.UNORDERED_LIST_ITEM
        pendingListDepth = prevDepth
      } else {
        pendingBlockType = BlockType.PARAGRAPH
        pendingListDepth = 0
      }
    }

    // Re-clamp every bullet span to its line's content.
    for (span in editable.getSpans(0, editable.length, InputBulletSpan::class.java)) {
      val (ls, le) = lineBounds(editable.getSpanStart(span))
      val depth = span.depth
      editable.removeSpan(span)
      if (le > ls) {
        editable.setSpan(InputBulletSpan(depth, displayDensity), ls, le, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        for (s in editable.getSpans(ls, le, InputListItemSpacingSpan::class.java)) editable.removeSpan(s)
        applyListItemSpacingSpan(editable, ls, le)
      }
    }
  }

  /**
   * Tab indents the current list item (Shift+Tab outdents); Backspace at the
   * start of an item outdents, then removes the list marker at depth 0. Keeps
   * list nesting keyboard-editable on hardware keyboards. Returns true if handled.
   */
  private fun handleListKey(
    keyCode: Int,
    event: KeyEvent?,
  ): Boolean {
    if (blockTypeAtCursor() != BlockType.UNORDERED_LIST_ITEM) return false
    when (keyCode) {
      KeyEvent.KEYCODE_TAB -> {
        if (event?.isShiftPressed == true) outdentList() else indentList()
        return true
      }

      KeyEvent.KEYCODE_DEL -> {
        if (selectionStart == selectionEnd) {
          val (ls, le) = lineBounds(selectionStart)
          val content = text?.subSequence(ls, le)?.toString() ?: ""
          // At the item's start, or on an empty/ZWSP-anchored item (caret sits
          // after the anchor, not at the line start) — outdent, then un-list.
          if (selectionStart == ls || content.isEmpty() || content == "\u200B") {
            if (listDepthAtCursor() > 0) outdentList() else toggleUnorderedList()
            return true
          }
        }
      }
    }
    return false
  }

  // endregion

  fun setLinkForSelection(url: String) {
    val selStart = selectionStart
    val selEnd = selectionEnd
    if (selStart == selEnd) return

    val editable = text
    if (editable != null) {
      autoLinkDetector.clearAutoLinkInRange(editable, selStart, selEnd)
    }
    formattingStore.addRange(FormattingRange(StyleType.LINK, selStart, selEnd, url))
    applyFormattingAndEmit()
  }

  fun insertLinkAtCursor(
    displayText: String,
    url: String,
  ) {
    val editable = text ?: return
    val selStart = selectionStart
    val selEnd = selectionEnd
    val linkEnd = selStart + displayText.length

    isProcessingTextChange = true
    try {
      editable.replace(selStart, selEnd, displayText)
      formattingStore.adjustForEdit(selStart, selEnd - selStart, displayText.length)
      autoLinkDetector.clearAutoLinkInRange(editable, selStart, linkEnd)
      formattingStore.addRange(FormattingRange(StyleType.LINK, selStart, linkEnd, sanitizeLinkUrl(url)))
      lastProcessedText = editable.toString()

      setSelection(linkEnd)
      applyFormattingAndEmit()
      eventEmitter.emitChangeText()
    } finally {
      isProcessingTextChange = false
    }
  }

  fun insertMention(
    displayText: String,
    url: String,
  ) {
    if (displayText.isEmpty()) return
    val indicator = activeMentionIndicator ?: return
    val start = activeMentionStart
    val end = activeMentionEnd
    val editable = text ?: return
    if (start < 0 || end < start || end > editable.length) return

    val sanitizedUrl = sanitizeLinkUrl(url)
    val shouldAppendSpace = end >= editable.length || !editable[end].isWhitespace()
    val replacement = if (shouldAppendSpace) "$displayText " else displayText
    val linkEnd = start + displayText.length

    isProcessingTextChange = true
    try {
      editable.replace(start, end, replacement)
      formattingStore.adjustForEdit(start, end - start, replacement.length)
      autoLinkDetector.clearAutoLinkInRange(editable, start, linkEnd)
      formattingStore.addRange(FormattingRange(StyleType.LINK, start, linkEnd, sanitizedUrl))
      lastProcessedText = editable.toString()

      clearActiveMention(emit = true, indicatorOverride = indicator)
      setSelection(start + replacement.length)
      applyFormattingAndEmit()
      eventEmitter.emitChangeText()
    } finally {
      isProcessingTextChange = false
    }
  }

  fun startMention(indicator: String) {
    if (indicator.isEmpty() || indicator !in mentionIndicators) return
    val editable = text ?: return
    val selStart = selectionStart
    val selEnd = selectionEnd

    isProcessingTextChange = true
    try {
      editable.replace(selStart, selEnd, indicator)
      formattingStore.adjustForEdit(selStart, selEnd - selStart, indicator.length)
      lastProcessedText = editable.toString()
      setSelection(selStart + indicator.length)
      applyFormattingAndEmit()
      eventEmitter.emitChangeText()
      updateActiveMention()
    } finally {
      isProcessingTextChange = false
    }
  }

  fun removeLinkAtCursor() {
    val pos = selectionStart
    val linkRange = formattingStore.rangeOfType(StyleType.LINK, pos) ?: return
    formattingStore.removeRange(linkRange)
    applyFormattingAndEmit()
  }

  fun deleteLinkBeforeCursor(): Boolean {
    val editable = text ?: return false
    val cursorStart = selectionStart
    val cursorEnd = selectionEnd
    if (cursorStart != cursorEnd || cursorStart <= 0) return false

    val linkRange = formattingStore.rangeOfType(StyleType.LINK, cursorStart - 1) ?: return false

    isProcessingTextChange = true
    try {
      editable.delete(linkRange.start, linkRange.end)
      formattingStore.adjustForEdit(linkRange.start, linkRange.length, 0)
      lastProcessedText = editable.toString()
      setSelection(linkRange.start.coerceAtMost(editable.length))
      applyFormattingAndEmit()
      eventEmitter.emitChangeText()
      clearActiveMention()
    } finally {
      isProcessingTextChange = false
    }
    return true
  }

  fun setMentionIndicators(indicators: List<String>) {
    val newIndicators = LinkedHashSet(indicators)
    if (newIndicators == mentionIndicators) return
    mentionIndicators = newIndicators
    activeMentionIndicator?.let { indicator ->
      if (indicator !in mentionIndicators) {
        clearActiveMention(emit = true, indicatorOverride = indicator)
      }
    }
    updateActiveMention()
  }

  fun dismissActiveMention() {
    clearActiveMention(emit = false)
  }

  fun setContextMenuItems(items: List<String>) {
    contextMenu.setContextMenuItems(items)
  }

  fun setLinkRegex(config: LinkRegexConfig) {
    autoLinkDetector.setRegexConfig(config)
  }

  fun setAutoLinkStyle(style: InputFormatterStyle) {
    autoLinkDetector.style = style
  }

  fun allFormattingRangesForSerialization(): List<FormattingRange> {
    val editable = text ?: return formattingStore.allRanges
    val transientRanges = detectorPipeline.allTransientFormattingRanges(editable)
    if (transientRanges.isEmpty()) return formattingStore.allRanges
    return formattingStore.allRanges + transientRanges
  }

  fun setValueFromJS(markdown: String) {
    val parsed = InputParser.parseToPlainTextAndRanges(markdown)
    blockEmitting = true
    try {
      runAsATransaction {
        formattingStore.clearAll()
        formattingStore.setRanges(parsed.formattingRanges)
        setText(parsed.plainText)
        applyBlockRanges(parsed.blockRanges)
        setSelection(text?.length ?: 0)
      }
      applyFormatting()
      forceScrollToSelection()
      layoutManager.invalidateLayout()
      lastProcessedText = text?.toString() ?: ""
    } finally {
      blockEmitting = false
    }
  }

  override fun setBackgroundColor(color: Int) {
    BackgroundStyleApplicator.setBackgroundColor(this, color)
  }

  fun setFontSizeFromProps(size: Float) {
    if (size <= 0f) return
    val sizePx = ceil(PixelUtil.toPixelFromSP(size))
    setTextSize(TypedValue.COMPLEX_UNIT_PX, sizePx)
    layoutManager.invalidateLayout()
  }

  fun setListItemSpacingFromProps(spacing: Float) {
    listItemSpacingPx = if (spacing > 0f) PixelUtil.toPixelFromDIP(spacing) else 0f
    val editable = text ?: return
    // Re-stamp existing list items so the spacing span is added/removed/resized.
    for (span in editable.getSpans(0, editable.length, InputListItemSpacingSpan::class.java)) {
      editable.removeSpan(span)
    }
    if (listItemSpacingPx > 0f) {
      for (span in bulletSpansIn(editable, 0, editable.length)) {
        applyListItemSpacingSpan(editable, editable.getSpanStart(span), editable.getSpanEnd(span))
      }
    }
    invalidate()
  }

  fun setColorFromProps(colorInt: Int?) {
    setTextColor(colorInt ?: Color.BLACK)
  }

  fun setCursorColorFromProps(colorInt: Int?) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val cursorDrawable = textCursorDrawable ?: return
      if (colorInt != null) {
        cursorDrawable.colorFilter = BlendModeColorFilter(colorInt, BlendMode.SRC_IN)
      } else {
        cursorDrawable.clearColorFilter()
      }
      textCursorDrawable = cursorDrawable
    }
  }

  fun setFontFamily(family: String?) {
    if (family != fontFamilyValue) {
      fontFamilyValue = family
      typefaceDirty = true
    }
  }

  fun setFontWeight(weight: String?) {
    val parsed = ReactTypefaceUtils.parseFontWeight(weight)
    if (parsed != fontWeightValue) {
      fontWeightValue = parsed
      typefaceDirty = true
    }
  }

  private fun updateTypeface() {
    if (!typefaceDirty) return
    typefaceDirty = false

    val newTypeface =
      ReactTypefaceUtils.applyStyles(
        typeface,
        ReactConstants.UNSET,
        fontWeightValue,
        fontFamilyValue,
        context.assets,
      )
    typeface = newTypeface
    paint.typeface = newTypeface
    layoutManager.invalidateLayout()
  }

  fun setAutoCapitalize(flagName: String?) {
    AutoCapitalizeUtils.apply(this, flagName)
  }

  fun requestFocusProgrammatically() {
    requestFocus()
    inputMethodManager?.showSoftInput(this, 0)
    setSelection(selectionStart.coerceAtLeast(0))
  }

  private fun showAutoFocusKeyboardIfPending() {
    if (!pendingAutoFocusKeyboard || !hasWindowFocus()) return
    pendingAutoFocusKeyboard = false
    inputMethodManager?.showSoftInput(this, 0)
  }

  fun afterUpdateTransaction() {
    updateTypeface()
    if (autoFocusRequested) {
      autoFocusRequested = false
      pendingAutoFocusKeyboard = true
      post {
        // afterUpdateTransaction runs before onAttachedToWindow, where requestFocus()/showSoftInput()
        // are dropped and setTextIsSelectable(true) would reset the caret to 0. Defer to the next loop
        // so focus sticks and the caret lands at end (matching iOS).
        requestFocus()
        setSelection(text?.length ?: 0)
        showAutoFocusKeyboardIfPending()
      }
    }
  }

  fun applyStyleToRange(
    styleType: StyleType,
    start: Int,
    end: Int,
  ) {
    if (start >= end) return
    val handler = formatter.handlers[styleType] ?: return
    val isActive = formattingStore.isStyleActive(styleType, start)
    if (isActive) {
      formattingStore.removeType(styleType, start, end)
    } else {
      for (conflict in handler.mergingConfig.conflictingStyles) {
        formattingStore.removeType(conflict, start, end)
      }
      formattingStore.addRange(FormattingRange(styleType, start, end))
    }
    applyFormattingAndEmit()
  }

  fun applyLinkToRange(
    url: String,
    start: Int,
    end: Int,
  ) {
    if (start >= end) return
    formattingStore.addRange(FormattingRange(StyleType.LINK, start, end, url))
    applyFormattingAndEmit()
  }

  private fun updateActiveMention() {
    val plainText = text?.toString() ?: return
    val cursor = selectionStart
    if (selectionStart != selectionEnd || cursor < 0 || cursor > plainText.length) {
      clearActiveMention()
      return
    }

    val candidate = detectMentionAtCursor(plainText, cursor)
    if (candidate == null) {
      clearActiveMention()
      return
    }

    if (activeMentionIndicator != candidate.indicator || activeMentionStart != candidate.start) {
      activeMentionIndicator?.let { eventEmitter.emitEndMention(it) }
      activeMentionIndicator = candidate.indicator
      activeMentionStart = candidate.start
      eventEmitter.emitStartMention(candidate.indicator)
    }

    activeMentionEnd = candidate.end
    if (activeMentionText != candidate.text) {
      activeMentionText = candidate.text
      eventEmitter.emitChangeMention(candidate.indicator, candidate.text)
    }
  }

  private fun detectMentionAtCursor(
    plainText: String,
    cursor: Int,
  ): MentionCandidate? {
    if (mentionIndicators.isEmpty()) return null

    val start = WordsUtils.tokenStart(plainText, cursor)
    val token = plainText.substring(start, cursor)
    val indicator = mentionIndicators.firstOrNull { token.startsWith(it) } ?: return null
    if (formattingStore.rangeOfType(StyleType.LINK, start) != null) return null

    return MentionCandidate(
      indicator = indicator,
      start = start,
      end = cursor,
      text = token.substring(indicator.length),
    )
  }

  private fun clearActiveMention(
    emit: Boolean = true,
    indicatorOverride: String? = null,
  ) {
    val indicator = indicatorOverride ?: activeMentionIndicator
    activeMentionIndicator = null
    activeMentionStart = -1
    activeMentionEnd = -1
    activeMentionText = ""
    if (emit && indicator != null) {
      eventEmitter.emitEndMention(indicator)
    }
  }

  private fun sanitizeLinkUrl(url: String): String =
    url
      .replace("(", "%28")
      .replace(")", "%29")

  private data class MentionCandidate(
    val indicator: String,
    val start: Int,
    val end: Int,
    val text: String,
  )
}
