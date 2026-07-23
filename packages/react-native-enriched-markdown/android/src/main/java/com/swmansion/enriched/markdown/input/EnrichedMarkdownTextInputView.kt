package com.swmansion.enriched.markdown.input

import android.content.ClipboardManager
import android.content.Context
import android.graphics.BlendMode
import android.graphics.BlendModeColorFilter
import android.graphics.Color
import android.os.Build
import android.text.Editable
import android.text.InputType
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
import com.swmansion.enriched.markdown.input.formatting.BlockStore
import com.swmansion.enriched.markdown.input.formatting.FormattingStore
import com.swmansion.enriched.markdown.input.formatting.InputFormatter
import com.swmansion.enriched.markdown.input.formatting.InputParser
import com.swmansion.enriched.markdown.input.formatting.MarkdownSerializer
import com.swmansion.enriched.markdown.input.layout.InputEventEmitter
import com.swmansion.enriched.markdown.input.layout.InputLayoutManager
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.model.BlockType
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.InputFormatterStyle
import com.swmansion.enriched.markdown.input.model.StyleType
import com.swmansion.enriched.markdown.input.toolbar.InputContextMenu
import com.swmansion.enriched.markdown.utils.input.AutoCapitalizeUtils
import kotlin.math.ceil

private fun Char.isLineBreak(): Boolean = this == '\n' || this == '\r' || this == '\u0085' || this == '\u2028' || this == '\u2029'

class EnrichedMarkdownTextInputView(
  context: Context,
) : AppCompatEditText(context) {
  private var isComponentReady = false

  val formattingStore = FormattingStore()
  val blockStore = BlockStore()
  val formatter = InputFormatter()
  val pendingStyles = mutableSetOf<StyleType>()
  val pendingStyleRemovals = mutableSetOf<StyleType>()

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

  private var headingOverrideBaseSizePx: Float? = null
  private var baseHintColor: Int? = null

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

  // Plain Tab is consumed before the platform's focus navigation so it inserts
  // a tab character and emits onKeyPress, matching iOS. Shift/Ctrl+Tab still
  // navigate focus.
  override fun onKeyDown(
    keyCode: Int,
    event: KeyEvent?,
  ): Boolean {
    if (keyCode == KeyEvent.KEYCODE_TAB && event?.hasNoModifiers() != false) {
      eventEmitter.emitKeyPress("Tab")
      val start = minOf(selectionStart, selectionEnd).coerceAtLeast(0)
      val end = maxOf(selectionStart, selectionEnd).coerceAtLeast(0)
      text?.replace(start, end, "\t")
      return true
    }
    if (keyCode == KeyEvent.KEYCODE_DEL && deleteLinkBeforeCursor()) {
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
      adjustStoresForEdit(editStart, deletedLength, insertedLength)
      applyPendingStyles(editStart, insertedLength)
      applyFormattingScopedToEdit(editStart, insertedLength)

      val editable = text
      if (editable != null) {
        detectorPipeline.processTextChange(editable, currentText, editStart, insertedLength)
      }

      forceScrollToSelection()
      syncCursorSizeWithBlock()
      eventEmitter.emitChangeText()
      if (emitMarkdown) eventEmitter.emitChangeMarkdown()
      updateActiveMention()
      eventEmitter.emitCaretRectChangeIfNeeded()
      isTextChanging = false
      didTextChangeRecently = true
      lastProcessedText = currentText
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
      // Links (e.g. mentions) are atomic: snap a partial selection to the whole link, and a caret
      // inside a link to its end. Returning lets the recursive onSelectionChanged emit for the result.
      formattingStore.selectionAdjustedForAtomicLinks(selStart, selEnd)?.let { (newStart, newEnd) ->
        setSelection(newStart, newEnd)
        return
      }
      if (didTextChangeRecently) {
        didTextChangeRecently = false
      } else {
        pendingStyles.clear()
        pendingStyleRemovals.clear()
      }
    }

    eventEmitter.emitSelection(selStart, selEnd)
    updateActiveMention()
    eventEmitter.emitState()
    eventEmitter.emitCaretRectChangeIfNeeded()
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

  /**
   * Drops heading ranges no longer anchored at a line start (e.g. Backspace merged
   * their line into the previous one). Must run BEFORE [BlockStore.normalizeToLineBounds]
   * so a merged range is judged on its unsnapped anchor and can't grow over the line
   * it merged into.
   */
  private fun pruneOrphanedHeadingAnchors() {
    val editable = text ?: return
    val orphans =
      blockStore.allRanges.filter { range ->
        range.type in BlockType.HEADINGS && !isAtLineStart(editable, range.start)
      }
    for (orphan in orphans) {
      blockStore.removeBlock(orphan.start, orphan.start, editable)
    }
  }

  /** True when [pos] is the first character of a line (document start or just after a line break). */
  private fun isAtLineStart(
    editable: CharSequence,
    pos: Int,
  ): Boolean {
    if (pos < 0 || pos > editable.length) return false
    return pos == 0 || editable[pos - 1].isLineBreak()
  }

  /**
   * Adjusts both [formattingStore] and [blockStore] for a text edit, then prunes
   * orphaned heading anchors and normalizes block ranges to line bounds. Every
   * code path that mutates the text buffer must call this so block ranges stay in
   * sync — mirrors iOS's `replaceTextInRange:withText:formattingRanges:blockRanges:`.
   */
  private fun adjustStoresForEdit(
    editStart: Int,
    deletedLength: Int,
    insertedLength: Int,
  ) {
    formattingStore.adjustForEdit(editStart, deletedLength, insertedLength)
    blockStore.adjustForEdit(editStart, deletedLength, insertedLength)
    pruneOrphanedHeadingAnchors()
    text?.let { blockStore.normalizeToLineBounds(it) }
  }

  private inline fun replaceTextInRange(
    start: Int,
    end: Int,
    newText: String,
    postAdjust: (Editable) -> Unit = {},
  ) {
    val editable = text ?: return
    isProcessingTextChange = true
    try {
      editable.replace(start, end, newText)
      adjustStoresForEdit(start, end - start, newText.length)
      postAdjust(editable)
      lastProcessedText = editable.toString()
      applyFormattingAndEmit()
      eventEmitter.emitChangeText()
    } finally {
      isProcessingTextChange = false
    }
  }

  fun applyFormatting() {
    val editable = text ?: return
    formatter.applyFormatting(editable, formattingStore.allRanges)
    formatter.applyBlockFormatting(editable, blockStore.allRanges)
  }

  /**
   * Re-applies inline formatting across the document, but re-normalizes block spans
   * only on the paragraph(s) touched by an edit at `[editStart, editStart + insertedLength)`.
   * Heading sizing is paragraph-scoped, so re-stamping only the edited line keeps
   * per-keystroke work bounded instead of re-spanning the whole document.
   */
  private fun applyFormattingScopedToEdit(
    editStart: Int,
    insertedLength: Int,
  ) {
    val editable = text ?: return
    formatter.applyFormatting(editable, formattingStore.allRanges)

    val length = editable.length
    val rawStart = editStart.coerceIn(0, length)
    val rawEnd = (editStart + insertedLength).coerceIn(rawStart, length)

    // Expand the edit span to whole-line bounds: a heading span covers its line, so
    // re-stamping must cover every line the edit touched, edge-to-edge.
    var lineStart = rawStart
    while (lineStart > 0 && editable[lineStart - 1] != '\n') lineStart--
    var lineEnd = rawEnd
    while (lineEnd < length && editable[lineEnd] != '\n') lineEnd++

    formatter.applyBlockFormatting(editable, blockStore.allRanges, lineStart, lineEnd)
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

  // Copies the whole input as markdown without disturbing the current selection,
  // tagged so paste restores formatting and block ranges — mirrors iOS, which
  // stores markdown under its custom pasteboard type.
  fun copyToClipboard() {
    val content = text
    if (content.isNullOrEmpty()) return
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
    val markdown =
      MarkdownSerializer.serialize(
        content.toString(),
        allFormattingRangesForSerialization(),
        blockStore.allRanges,
      ) { blockRange ->
        formatter.handlerForBlock(blockRange.type)?.markdownLinePrefix(blockRange) ?: ""
      }
    clipboard.setPrimaryClip(MarkdownClipboard.newMarkdownClip(markdown, content.toString()))
  }

  // Copy/cut re-tag the clip with markdown and paste restores it, so formatting
  // and block ranges survive the round trip — mirrors iOS's copy:/cut:/paste:
  // overrides. External clips keep default handling.
  override fun onTextContextMenuItem(id: Int): Boolean {
    if (id == android.R.id.paste) {
      MarkdownClipboard.markdownFromClipboard(context)?.let { markdown ->
        pasteMarkdown(markdown)
        return true
      }
    }
    if (id == android.R.id.copy || id == android.R.id.cut) {
      val selStart = selectionStart
      val selEnd = selectionEnd
      val plainText = if (selStart < selEnd) text?.substring(selStart, selEnd) else null
      val markdown = markdownForSelectedRange()
      val handled = super.onTextContextMenuItem(id)
      if (handled && markdown != null && plainText != null) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        clipboard?.setPrimaryClip(MarkdownClipboard.newMarkdownClip(markdown, plainText))
      }
      return handled
    }
    return super.onTextContextMenuItem(id)
  }

  /** Serializes the current selection (inline + block ranges) to markdown, or null if empty. */
  fun markdownForSelectedRange(): String? {
    val selStart = selectionStart
    val selEnd = selectionEnd
    if (selStart >= selEnd) return null

    val fullText = text?.toString() ?: return null
    val selectedText = fullText.substring(selStart, selEnd)

    val clippedRanges = mutableListOf<FormattingRange>()
    for (range in formattingStore.allRanges) {
      if (range.end <= selStart || range.start >= selEnd) continue

      val clippedStart = maxOf(range.start, selStart)
      val clippedEnd = minOf(range.end, selEnd)
      clippedRanges.add(
        FormattingRange(range.type, clippedStart - selStart, clippedEnd - selStart, range.url),
      )
    }

    val clippedBlockRanges = mutableListOf<BlockRange>()
    for (blockRange in blockStore.allRanges) {
      if (blockRange.end <= selStart || blockRange.start >= selEnd) continue

      val clippedStart = maxOf(blockRange.start, selStart)
      val clippedEnd = minOf(blockRange.end, selEnd)
      clippedBlockRanges.add(
        BlockRange(blockRange.type, clippedStart - selStart, clippedEnd - selStart, blockRange.level),
      )
    }

    return MarkdownSerializer.serialize(selectedText, clippedRanges, clippedBlockRanges) { blockRange ->
      formatter.handlerForBlock(blockRange.type)?.markdownLinePrefix(blockRange) ?: ""
    }
  }

  /**
   * Replaces the selection with parsed markdown, importing its inline formatting
   * and block ranges (headings etc.) into the stores — mirrors iOS pasteMarkdown.
   */
  fun pasteMarkdown(markdown: String) {
    val editable = text ?: return
    val parsed = InputParser.parseToPlainTextAndRanges(markdown)
    val selStart = selectionStart.coerceIn(0, editable.length)
    val selEnd = selectionEnd.coerceIn(selStart, editable.length)

    replaceTextInRange(selStart, selEnd, parsed.plainText) { editable ->
      for (range in parsed.formattingRanges) {
        formattingStore.addRange(
          FormattingRange(range.type, range.start + selStart, range.end + selStart, range.url),
        )
      }
      for (block in parsed.blockRanges) {
        blockStore.setBlock(block.type, block.level, block.start + selStart, block.end + selStart, editable)
      }
      setSelection(selStart + parsed.plainText.length)
      detectorPipeline.processTextChange(editable, editable.toString(), selStart, parsed.plainText.length)
    }
  }

  /** Toggles a heading (H1-H6) on the cursor's paragraph(s); the active level toggles back to a paragraph. */
  fun toggleHeading(level: Int) {
    val blockType = BlockType.forHeadingLevel(level) ?: return
    toggleBlockType(blockType, level)
  }

  /**
   * Block counterpart to [toggleInlineStyle]: sets [type] on the paragraph(s) the
   * selection touches, or clears it back to a plain paragraph when already active.
   */
  private fun toggleBlockType(
    type: BlockType,
    level: Int,
  ) {
    val editable = text ?: return

    val selStart = selectionStart.coerceIn(0, editable.length)
    val selEnd = selectionEnd.coerceIn(selStart, editable.length)

    val existing = blockOnParagraphAt(selStart)
    val isActive = existing != null && existing.type == type && existing.level == level

    if (isActive) {
      blockStore.removeBlock(selStart, selEnd, editable)
    } else {
      // Blocks are single-paragraph: set one range per line the selection
      // touches, not one range spanning them all — otherwise the next edit's
      // line normalization would clip the block to its first line.
      var lineStart = selStart
      while (lineStart > 0 && !editable[lineStart - 1].isLineBreak()) lineStart--
      while (lineStart <= selEnd) {
        var lineEnd = lineStart
        while (lineEnd < editable.length && !editable[lineEnd].isLineBreak()) lineEnd++
        blockStore.setBlock(type, level, lineStart, lineEnd, editable)
        lineStart = lineEnd + 1
      }
    }

    applyFormattingAndEmit()
    syncCursorSizeWithBlock()
  }

  /**
   * The block owning [pos]'s paragraph, or null. Matched by line start, not
   * containment, so line-end carets and zero-length heading anchors register.
   */
  private fun blockOnParagraphAt(pos: Int): BlockRange? {
    val editable = text ?: return null
    val cursor = pos.coerceIn(0, editable.length)
    var lineStart = cursor
    while (lineStart > 0 && !editable[lineStart - 1].isLineBreak()) lineStart--
    return blockStore.allRanges.firstOrNull { it.start == lineStart }
  }

  /** Heading level (1-6) of the cursor's paragraph, or 0 when it is a plain paragraph. */
  fun headingLevelAtCursor(): Int {
    val block = blockOnParagraphAt(selectionStart) ?: return 0
    return if (block.type in BlockType.HEADINGS) block.level else 0
  }

  /**
   * On empty text with a heading block, overrides text size to the heading's
   * font size so the cursor matches heading height. Hides the hint while
   * active. Cleared automatically when text is typed or heading is toggled off.
   */
  private fun syncCursorSizeWithBlock() {
    val editable = text ?: return
    val block = blockOnParagraphAt(selectionStart)

    if (block != null && block.type in BlockType.HEADINGS && editable.isEmpty()) {
      val headingSizePx = formatter.resolveHeadingFontSizePx(block.level) ?: return
      if (headingOverrideBaseSizePx == null) {
        headingOverrideBaseSizePx = paint.textSize
        baseHintColor = currentHintTextColor
        setHintTextColor(Color.TRANSPARENT)
      }
      if (paint.textSize != headingSizePx) {
        setTextSize(TypedValue.COMPLEX_UNIT_PX, headingSizePx)
      }
    } else {
      headingOverrideBaseSizePx?.let { baseSizePx ->
        setTextSize(TypedValue.COMPLEX_UNIT_PX, baseSizePx)
        headingOverrideBaseSizePx = null
        baseHintColor?.let { setHintTextColor(it) }
        baseHintColor = null
      }
    }
  }

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
    val selStart = selectionStart
    val selEnd = selectionEnd
    val linkEnd = selStart + displayText.length

    replaceTextInRange(selStart, selEnd, displayText) { editable ->
      autoLinkDetector.clearAutoLinkInRange(editable, selStart, linkEnd)
      formattingStore.addRange(FormattingRange(StyleType.LINK, selStart, linkEnd, sanitizeLinkUrl(url)))
      setSelection(linkEnd)
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

    replaceTextInRange(start, end, replacement) { ed ->
      autoLinkDetector.clearAutoLinkInRange(ed, start, linkEnd)
      formattingStore.addRange(FormattingRange(StyleType.LINK, start, linkEnd, sanitizedUrl))
      clearActiveMention(emit = true, indicatorOverride = indicator)
      setSelection(start + replacement.length)
    }
  }

  fun startMention(indicator: String) {
    if (indicator.isEmpty() || indicator !in mentionIndicators) return
    val selStart = selectionStart
    val selEnd = selectionEnd

    replaceTextInRange(selStart, selEnd, indicator) {
      setSelection(selStart + indicator.length)
    }
    updateActiveMention()
  }

  fun removeLinkAtCursor() {
    val pos = selectionStart
    val linkRange = formattingStore.rangeOfType(StyleType.LINK, pos) ?: return
    formattingStore.removeRange(linkRange)
    applyFormattingAndEmit()
  }

  fun deleteLinkBeforeCursor(): Boolean {
    val cursorStart = selectionStart
    val cursorEnd = selectionEnd
    if (cursorStart != cursorEnd || cursorStart <= 0) return false
    if (text == null) return false

    val linkRange = formattingStore.rangeOfType(StyleType.LINK, cursorStart - 1) ?: return false

    replaceTextInRange(linkRange.start, linkRange.end, "") { editable ->
      setSelection(linkRange.start.coerceAtMost(editable.length))
    }
    clearActiveMention()
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
        blockStore.setRanges(parsed.blockRanges)
        setText(parsed.plainText)
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
