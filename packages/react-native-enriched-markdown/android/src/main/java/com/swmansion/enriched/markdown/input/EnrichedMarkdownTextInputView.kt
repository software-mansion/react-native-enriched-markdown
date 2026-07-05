package com.swmansion.enriched.markdown.input

import android.content.ClipboardManager
import android.content.Context
import android.content.res.ColorStateList
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
import com.swmansion.enriched.markdown.input.model.MAX_LIST_DEPTH
import com.swmansion.enriched.markdown.input.model.StyleType
import com.swmansion.enriched.markdown.input.toolbar.InputContextMenu
import com.swmansion.enriched.markdown.utils.input.AutoCapitalizeUtils
import kotlin.math.ceil

// Zero-width space: anchors an empty bullet line so the marker draws and the caret
// indents (Android won't apply a LeadingMarginSpan's indent to an empty paragraph).
// Stripped during serialization, so it never reaches the Markdown output.
private const val ZWSP = '\u200B'

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
  private var savedHintTextColors: ColorStateList? = null

  // Guards re-entrancy while the empty-list-line ZWSP anchor is managed (its
  // insert/delete + setSelection would otherwise loop back through the callbacks).
  private var isManagingAnchor = false

  // The consumer-set placeholder, hidden while a bullet is drawn on an empty editor.
  private var userHint: CharSequence? = null

  private var listItemSpacingPx = 0

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

  /**
   * Hardware-keyboard list editing: Tab indents the current item, Shift+Tab outdents,
   * and Backspace at the start of an item (or on an empty/ZWSP-anchored item) outdents,
   * then un-lists at depth 0. Only fires on a list line; returns true when handled.
   */
  private fun handleListKey(
    keyCode: Int,
    event: KeyEvent?,
  ): Boolean {
    val listBlock = listBlockAtCursor() ?: return false
    val depth = listBlock.level
    when (keyCode) {
      KeyEvent.KEYCODE_TAB -> {
        if (event?.isShiftPressed == true) outdentList() else indentList()
        return true
      }

      KeyEvent.KEYCODE_DEL -> {
        if (selectionStart == selectionEnd) {
          val editable = text ?: return false
          val ls = lineStartOf(editable, selectionStart)
          val le = lineEndOf(editable, selectionStart)
          val content = editable.subSequence(ls, le).toString()
          // At the item's start, or on an empty/ZWSP-anchored item (the caret sits
          // after the anchor, not at the line start).
          if (selectionStart == ls || content.isEmpty() || content == ZWSP.toString()) {
            if (depth > 0) outdentList() else toggleListType(listBlock.type)
            return true
          }
        }
      }
    }
    return false
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
      blockStore.adjustForEdit(editStart, deletedLength, insertedLength)
      pruneOrphanedAnchors()
      handleNewlineBlockContinuation(editStart, deletedLength, insertedLength)
      text?.let { blockStore.normalizeToLineBounds(it) }
      applyPendingStyles(editStart, insertedLength)
      // Settle the empty-bullet ZWSP anchor (insert/strip the char and re-snap ranges)
      // BEFORE stamping spans, so block formatting runs exactly once over the final
      // text/ranges — otherwise a pre-ZWSP anchor span and the post-ZWSP span would
      // both land on the empty line (the "double bullet" bug).
      val anchorChanged = syncEmptyListAnchor(restamp = false)
      // A newline insert/delete (list continuation/exit) or a ZWSP anchor change can
      // move spans across lines, where a per-line scoped re-stamp would miss a stale
      // bullet span. Re-stamp the whole document in those cases; scope to the edited
      // line for ordinary typing to keep per-keystroke work bounded.
      val touchedNewline =
        anchorChanged ||
          editTouchedNewline(editStart, deletedLength, insertedLength, currentText)
      applyInlineFormatting()
      if (touchedNewline) {
        text?.let { formatter.applyBlockFormatting(it, blockStore.allRanges) }
      } else {
        applyBlockFormattingScopedToEdit(editStart, insertedLength)
      }

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
      // Record the post-pass text (block continuation / ZWSP sync may have mutated it),
      // so the next change detects equality correctly and doesn't reprocess.
      lastProcessedText = text?.toString() ?: currentText
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

    if (!isTextChanging && !isProcessingTextChange) {
      // The caret moving on/off an empty bullet line toggles the ZWSP anchor and the
      // placeholder visibility; skip during a text-change pass (handled there).
      syncEmptyListAnchor()
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
   * Drops anchored blocks (headings, list items) no longer anchored at a line start
   * (e.g. Backspace merged their line into the previous one). Must run BEFORE
   * [BlockStore.normalizeToLineBounds] so a merged range is judged on its unsnapped
   * anchor and can't grow over the line it merged into.
   */
  private fun pruneOrphanedAnchors() {
    val editable = text ?: return
    val orphans =
      blockStore.allRanges.filter { range ->
        range.type in BlockType.ANCHORED && !isAtLineStart(editable, range.start)
      }
    for (orphan in orphans) {
      blockStore.removeBlock(orphan.start, orphan.start, editable)
    }
  }

  /**
   * After a newline insertion, continues a block whose handler reports
   * [com.swmansion.enriched.markdown.input.styles.BlockHandler.continuesOnNewline]
   * (a list item) onto the new line as a sibling at the same depth, or exits the
   * block when the emptied item gets a second Enter.
   */
  private fun handleNewlineBlockContinuation(
    editStart: Int,
    deletedLength: Int,
    insertedLength: Int,
  ) {
    val editable = text ?: return
    if (deletedLength != 0 || insertedLength <= 0) return
    val insertedEnd = (editStart + insertedLength).coerceAtMost(editable.length)
    val insertedNewline = (editStart until insertedEnd).any { editable[it] == '\n' }
    if (!insertedNewline) return

    // The line the Enter was pressed on ends at the inserted newline.
    val prevLineEnd = editStart
    var prevLineStart = prevLineEnd
    while (prevLineStart > 0 && editable[prevLineStart - 1] != '\n') prevLineStart--

    val prevBlock = blockStore.allRanges.firstOrNull { it.start == prevLineStart } ?: return
    val handler = formatter.handlerForBlock(prevBlock.type) ?: return
    if (!handler.continuesOnNewline) return

    val prevContentLength = (prevLineStart until prevLineEnd).count { editable[it] != ZWSP }
    if (prevContentLength == 0) {
      // Exit: clear the block AND delete the just-inserted newline so the empty
      // item collapses in place instead of leaving an extra indented blank line.
      blockStore.removeBlock(prevLineStart, prevLineEnd, editable)
      val newlineEnd = (editStart + insertedLength).coerceAtMost(editable.length)
      runAsATransaction { editable.delete(editStart, newlineEnd) }
      blockStore.adjustForEdit(editStart, insertedLength, 0)
      setSelection(prevLineStart.coerceAtMost(editable.length))
      return
    }

    val newLineStart = (editStart + insertedLength).coerceAtMost(editable.length)
    blockStore.setBlock(prevBlock.type, prevBlock.level, newLineStart, newLineStart, editable)
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
   * orphaned anchors and normalizes block ranges to line bounds. Every code path
   * that mutates the text buffer must call this so block ranges stay in sync —
   * mirrors iOS's `replaceTextInRange:withText:formattingRanges:blockRanges:`.
   */
  private fun adjustStoresForEdit(
    editStart: Int,
    deletedLength: Int,
    insertedLength: Int,
  ) {
    formattingStore.adjustForEdit(editStart, deletedLength, insertedLength)
    blockStore.adjustForEdit(editStart, deletedLength, insertedLength)
    pruneOrphanedAnchors()
    text?.let { blockStore.normalizeToLineBounds(it) }
  }

  fun applyFormatting() {
    val editable = text ?: return
    formatter.applyFormatting(editable, formattingStore.allRanges)
    formatter.applyBlockFormatting(editable, blockStore.allRanges)
  }

  /** Re-applies inline (character) formatting across the whole document. */
  private fun applyInlineFormatting() {
    val editable = text ?: return
    formatter.applyFormatting(editable, formattingStore.allRanges)
  }

  /**
   * Re-stamps block spans only on the paragraph(s) touched by an edit at
   * `[editStart, editStart + insertedLength)`. A block span covers its whole line, so
   * re-stamping only the edited line keeps per-keystroke work bounded instead of
   * re-spanning the whole document. Safe only for edits that stay within a line; a
   * newline-crossing edit must re-stamp the whole document (see [onAfterTextChanged]).
   */
  private fun applyBlockFormattingScopedToEdit(
    editStart: Int,
    insertedLength: Int,
  ) {
    val editable = text ?: return
    val length = editable.length
    val rawStart = editStart.coerceIn(0, length)
    val rawEnd = (editStart + insertedLength).coerceIn(rawStart, length)

    // Expand the edit span to whole-line bounds: a block span covers its line, so
    // re-stamping must cover every line the edit touched, edge-to-edge.
    var lineStart = rawStart
    while (lineStart > 0 && editable[lineStart - 1] != '\n') lineStart--
    var lineEnd = rawEnd
    while (lineEnd < length && editable[lineEnd] != '\n') lineEnd++

    formatter.applyBlockFormatting(editable, blockStore.allRanges, lineStart, lineEnd)
  }

  /**
   * True when the edit inserted or deleted a line break (so block spans may need to
   * move across lines). Checks the inserted run in the current text and the deleted run
   * in the pre-edit text.
   */
  private fun editTouchedNewline(
    editStart: Int,
    deletedLength: Int,
    insertedLength: Int,
    preEditText: String,
  ): Boolean {
    val editable = text
    if (editable != null && insertedLength > 0) {
      val end = (editStart + insertedLength).coerceAtMost(editable.length)
      if ((editStart until end).any { editable[it].isLineBreak() }) return true
    }
    if (deletedLength > 0) {
      val end = (editStart + deletedLength).coerceAtMost(preEditText.length)
      if ((editStart until end).any { preEditText[it].isLineBreak() }) return true
    }
    return false
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

  /** The list block owning the caret's paragraph, or null. */
  private fun listBlockAtCursor(): BlockRange? = blockOnParagraphAt(selectionStart)?.takeIf { it.type in BlockType.LIST_ITEMS }

  /**
   * List state of the cursor's paragraph for [type]: whether it is such an item and,
   * if so, its 0-based nesting depth. The orchestrator side of the
   * `onChangeState.unorderedList` / `orderedList` payloads.
   */
  fun listStateAtCursor(type: BlockType): Pair<Boolean, Int> {
    val block = listBlockAtCursor() ?: return false to 0
    return if (block.type == type) true to block.level else false to 0
  }

  fun toggleUnorderedList() = toggleListType(BlockType.UNORDERED_LIST_ITEM)

  fun toggleOrderedList() = toggleListType(BlockType.ORDERED_LIST_ITEM)

  /**
   * Toggles a list of [type] on the cursor's paragraph(s): turns the touched lines
   * into depth-0 items (replacing an item of the other list type), or clears them
   * back to plain paragraphs when the cursor's line already carries [type].
   */
  private fun toggleListType(type: BlockType) {
    val editable = text ?: return
    val turningOff = listBlockAtCursor()?.type == type
    if (turningOff) {
      forEachSelectedLine { ls, le -> blockStore.removeBlock(ls, le, editable) }
    } else {
      setListBlockOnLines(type, 0)
    }
    blockStore.normalizeToLineBounds(editable)
    applyFormattingAndEmit()
    syncEmptyListAnchor()
  }

  /** Increases the nesting depth of the selected list item(s). QoL: indenting a plain paragraph starts a list. */
  fun indentList() = changeListDepthBy(1)

  /** Decreases the nesting depth; outdenting at depth 0 removes the list marker. */
  fun outdentList() = changeListDepthBy(-1)

  private fun changeListDepthBy(delta: Int) {
    val cursorBlock = listBlockAtCursor()
    if (cursorBlock == null) {
      // Indent on a plain paragraph starts a bullet list; headings/outdent are ignored.
      if (delta > 0 && blockOnParagraphAt(selectionStart) == null) toggleUnorderedList()
      return
    }
    if (delta < 0 && cursorBlock.level == 0) {
      toggleListType(cursorBlock.type)
      return
    }
    val editable = text ?: return
    forEachSelectedLine { ls, le ->
      val block = blockStore.allRanges.firstOrNull { it.start == ls && it.type in BlockType.LIST_ITEMS }
      if (block != null) {
        val newDepth = (block.level + delta).coerceIn(0, MAX_LIST_DEPTH)
        blockStore.setBlock(block.type, newDepth, ls, le, editable)
      }
    }
    blockStore.normalizeToLineBounds(editable)
    applyFormattingAndEmit()
    syncEmptyListAnchor()
  }

  /** Sets a [type] list block at [depth] on every line the selection touches. */
  private fun setListBlockOnLines(
    type: BlockType,
    depth: Int,
  ) {
    val editable = text ?: return
    forEachSelectedLine { ls, le ->
      blockStore.setBlock(type, depth, ls, le, editable)
    }
  }

  /** Runs [action] with the `[lineStart, lineEnd)` content bounds of each line the selection touches. */
  private inline fun forEachSelectedLine(action: (lineStart: Int, lineEnd: Int) -> Unit) {
    val editable = text ?: return
    val selEnd = selectionEnd.coerceIn(0, editable.length)
    var cursor = selectionStart.coerceIn(0, editable.length)
    while (cursor > 0 && !editable[cursor - 1].isLineBreak()) cursor--
    while (cursor <= editable.length) {
      var le = cursor
      while (le < editable.length && !editable[le].isLineBreak()) le++
      action(cursor, le)
      if (le >= selEnd) break
      cursor = le + 1
    }
  }

  /**
   * Keeps an empty bullet line anchored by a ZWSP so its marker draws and the caret
   * indents (a [android.text.style.LeadingMarginSpan] doesn't indent an empty
   * paragraph). Inserts the ZWSP on the caret's empty list line, strips stale ones.
   *
   * @param restamp re-apply block formatting here (selection/command paths); the
   *   text-change pass passes false and stamps once afterwards.
   * @return true if an anchor was inserted or stripped (text/ranges mutated).
   */
  private fun syncEmptyListAnchor(restamp: Boolean = true): Boolean {
    if (isManagingAnchor) return false
    val editable = text ?: return false
    isManagingAnchor = true
    var anchorChanged = false
    try {
      // Strip every stale ZWSP first (a line that gained content or stopped being a list).
      var i = editable.length - 1
      while (i >= 0) {
        if (editable[i] == ZWSP) {
          val ls = lineStartOf(editable, i)
          val le = lineEndOf(editable, i)
          val onlyZwsp = le - ls == 1 && editable[ls] == ZWSP
          val isEmptyListLine = onlyZwsp && blockStore.allRanges.any { it.start == ls && it.type in BlockType.LIST_ITEMS }
          if (!isEmptyListLine) {
            runAsATransaction { editable.delete(i, i + 1) }
            blockStore.adjustForEdit(i, 1, 0)
            anchorChanged = true
          }
        }
        i--
      }

      // Anchor the caret's line if it is an empty list item with no ZWSP yet.
      val caret = selectionStart
      if (selectionStart == selectionEnd) {
        val ls = lineStartOf(editable, caret)
        val le = lineEndOf(editable, caret)
        val block = blockStore.allRanges.firstOrNull { it.start == ls && it.type in BlockType.LIST_ITEMS }
        if (block != null && le == ls) {
          runAsATransaction { editable.insert(ls, ZWSP.toString()) }
          blockStore.adjustForEdit(ls, 0, 1)
          blockStore.normalizeToLineBounds(editable)
          setSelection(ls + 1)
          anchorChanged = true
        }
      }

      if (anchorChanged) {
        // Re-snap any range left zero-length by a strip so the next stamp is exact.
        blockStore.normalizeToLineBounds(editable)
        if (restamp) applyFormatting()
        lastProcessedText = editable.toString()
        if (emitMarkdown) eventEmitter.emitChangeMarkdown()
      }
      syncHintVisibility()
      return anchorChanged
    } finally {
      isManagingAnchor = false
    }
  }

  /**
   * The hint shows only on a truly empty editor with no block range — a bullet's
   * ZWSP anchor counts as content, so the hint never overlaps a marker. Mirrors iOS.
   */
  private fun syncHintVisibility() {
    val content = text
    val hasRealText = content != null && content.any { it != ZWSP }
    val hasBlock = blockStore.allRanges.isNotEmpty()
    val target: CharSequence? = if (hasRealText || hasBlock) "" else userHint
    if (hint != target) super.setHint(target)
  }

  fun setUserHint(value: CharSequence?) {
    userHint = value
    syncHintVisibility()
  }

  private fun lineStartOf(
    editable: CharSequence,
    pos: Int,
  ): Int {
    var s = pos.coerceIn(0, editable.length)
    while (s > 0 && !editable[s - 1].isLineBreak()) s--
    return s
  }

  private fun lineEndOf(
    editable: CharSequence,
    pos: Int,
  ): Int {
    var e = pos.coerceIn(0, editable.length)
    while (e < editable.length && !editable[e].isLineBreak()) e++
    return e
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
      // External plain text is treated as markdown so pasted syntax ("- ", "#",
      // "**") formats instead of landing literal; syntax-free text is unchanged.
      // "Paste as plain text" (pasteAsPlainText) keeps the literal default.
      plainTextFromClipboard()?.let { plainText ->
        pasteMarkdown(plainText)
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

  private fun plainTextFromClipboard(): String? {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return null
    val item = clipboard.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0) ?: return null
    return item.coerceToText(context)?.toString()?.takeIf { it.isNotEmpty() }
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

    isProcessingTextChange = true
    try {
      editable.replace(selStart, selEnd, parsed.plainText)
      adjustStoresForEdit(selStart, selEnd - selStart, parsed.plainText.length)

      for (range in parsed.formattingRanges) {
        formattingStore.addRange(
          FormattingRange(range.type, range.start + selStart, range.end + selStart, range.url),
        )
      }
      for (block in parsed.blockRanges) {
        blockStore.setBlock(block.type, block.level, block.start + selStart, block.end + selStart, editable)
      }

      val currentText = editable.toString()
      lastProcessedText = currentText
      setSelection(selStart + parsed.plainText.length)
      applyFormattingAndEmit()
      detectorPipeline.processTextChange(editable, currentText, selStart, parsed.plainText.length)
      eventEmitter.emitChangeText()
    } finally {
      isProcessingTextChange = false
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

    blockStore.normalizeToLineBounds(editable)
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
        savedHintTextColors = hintTextColors
      }
      if (paint.textSize != headingSizePx) {
        setTextSize(TypedValue.COMPLEX_UNIT_PX, headingSizePx)
        setHintTextColor(Color.TRANSPARENT)
      }
    } else {
      headingOverrideBaseSizePx?.let { baseSizePx ->
        setTextSize(TypedValue.COMPLEX_UNIT_PX, baseSizePx)
        headingOverrideBaseSizePx = null
        savedHintTextColors?.let { setHintTextColor(it) }
        savedHintTextColors = null
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
    val editable = text ?: return
    val selStart = selectionStart
    val selEnd = selectionEnd
    val linkEnd = selStart + displayText.length

    isProcessingTextChange = true
    try {
      editable.replace(selStart, selEnd, displayText)
      adjustStoresForEdit(selStart, selEnd - selStart, displayText.length)
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
      adjustStoresForEdit(start, end - start, replacement.length)
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
      adjustStoresForEdit(selStart, selEnd - selStart, indicator.length)
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
      adjustStoresForEdit(linkRange.start, linkRange.length, 0)
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

  // The markdownStyle prop, kept so density + listItemSpacing (sourced outside the
  // prop) can be folded into the formatter style whenever any of them changes.
  private var baseStyle: InputFormatterStyle? = null

  /**
   * Applies the parsed `markdownStyle`, folding in the display density and the current
   * `listItemSpacing` so block handlers can build density-correct, spacing-aware spans.
   * Returns true if the effective style changed (caller re-applies formatting).
   */
  fun setMarkdownStyleFromProps(style: InputFormatterStyle): Boolean {
    baseStyle = style
    setAutoLinkStyle(style)
    return applyComposedStyle()
  }

  private fun applyComposedStyle(): Boolean {
    val base = baseStyle ?: return false
    val composed = base.copy(displayDensity = resources.displayMetrics.density, listItemSpacingPx = listItemSpacingPx)
    return formatter.updateStyle(composed)
  }

  /** Sets the vertical spacing (dp) above each list item, re-stamping list spans. */
  fun setListItemSpacingFromProps(spacingDp: Float) {
    val px = if (spacingDp > 0f) PixelUtil.toPixelFromDIP(spacingDp).toInt() else 0
    if (px == listItemSpacingPx) return
    listItemSpacingPx = px
    if (applyComposedStyle()) applyFormatting()
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
