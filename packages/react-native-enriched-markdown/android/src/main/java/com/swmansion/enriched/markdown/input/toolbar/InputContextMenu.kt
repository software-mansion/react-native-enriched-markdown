package com.swmansion.enriched.markdown.input.toolbar

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.text.InputType
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.widget.EditText
import androidx.appcompat.app.AlertDialog
import com.swmansion.enriched.markdown.input.EnrichedMarkdownTextInputView
import com.swmansion.enriched.markdown.input.formatting.MarkdownSerializer
import com.swmansion.enriched.markdown.input.model.FormattingRange
import com.swmansion.enriched.markdown.input.model.StyleType

// TODO: Wrap all user-facing strings for localization support.

class InputContextMenu(
  private val view: EnrichedMarkdownTextInputView,
) {
  private var customItemTexts: List<String> = emptyList()

  fun setContextMenuItems(items: List<String>) {
    customItemTexts = items
  }

  fun install() {
    view.customSelectionActionModeCallback =
      object : ActionMode.Callback {
        override fun onCreateActionMode(
          mode: ActionMode,
          menu: Menu,
        ): Boolean = true

        override fun onPrepareActionMode(
          mode: ActionMode,
          menu: Menu,
        ): Boolean {
          menu.removeItem(MENU_FORMAT_ID)
          menu.removeItem(MENU_COPY_MARKDOWN_ID)
          menu.removeGroup(FORMAT_MENU_GROUP_ID)
          menu.removeGroup(CUSTOM_MENU_GROUP_ID)

          val formatSubMenu = menu.addSubMenu(FORMAT_MENU_GROUP_ID, MENU_FORMAT_ID, 100, "Format")
          FORMAT_ITEMS.forEachIndexed { index, (title, _) ->
            formatSubMenu.add(Menu.NONE, MENU_FORMAT_ITEM_BASE + index, index, title)
          }

          if (view.selectionStart < view.selectionEnd) {
            menu.add(FORMAT_MENU_GROUP_ID, MENU_COPY_MARKDOWN_ID, 101, "Copy as Markdown")

            customItemTexts.forEachIndexed { index, text ->
              menu
                .add(CUSTOM_MENU_GROUP_ID, MENU_CUSTOM_BASE + index, index, text)
                .setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
            }
          }

          return true
        }

        override fun onActionItemClicked(
          mode: ActionMode,
          item: MenuItem,
        ): Boolean {
          val itemId = item.itemId

          if (itemId == MENU_COPY_MARKDOWN_ID) {
            copyAsMarkdown()
            mode.finish()
            return true
          }

          val formatIndex = itemId - MENU_FORMAT_ITEM_BASE
          if (formatIndex in FORMAT_ITEMS.indices) {
            applyFormat(FORMAT_ITEMS[formatIndex].second)
            mode.finish()
            return true
          }

          val customIndex = itemId - MENU_CUSTOM_BASE
          if (customIndex in customItemTexts.indices) {
            val start = view.selectionStart
            val end = view.selectionEnd
            val selectedText = if (start < end) view.text?.substring(start, end) ?: "" else ""
            view.eventEmitter.emitContextMenuItemPress(customItemTexts[customIndex], selectedText, start, end)
            mode.finish()
            return true
          }

          return false
        }

        override fun onDestroyActionMode(mode: ActionMode) {}
      }
  }

  private fun applyFormat(styleType: StyleType) {
    val start = view.selectionStart
    val end = view.selectionEnd
    if (styleType == StyleType.LINK) {
      showLinkDialog(start, end)
      return
    }
    if (start < end) view.applyStyleToRange(styleType, start, end) else view.toggleInlineStyle(styleType)
  }

  private fun showLinkDialog(
    start: Int,
    end: Int,
  ) {
    val existingLink = view.formattingStore.rangeOfType(StyleType.LINK, start)
    val isEdit = existingLink != null

    val urlInput =
      EditText(view.context).apply {
        hint = "https://example.com"
        inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
        setSingleLine(true)
        existingLink?.url?.let { setText(it) }
      }

    AlertDialog
      .Builder(view.context)
      .setTitle(if (isEdit) "Edit Link" else "Add Link")
      .setView(urlInput)
      .setPositiveButton(if (isEdit) "Update" else "Add") { _, _ ->
        val url = urlInput.text.toString().trim()
        if (url.isNotEmpty()) view.applyLinkToRange(url, start, end)
      }.setNegativeButton("Cancel", null)
      .show()
  }

  private fun markdownForSelectedRange(): String? {
    val selStart = view.selectionStart
    val selEnd = view.selectionEnd
    if (selStart >= selEnd) return null

    val fullText = view.text?.toString() ?: return null
    val selectedText = fullText.substring(selStart, selEnd)

    val clippedRanges = mutableListOf<FormattingRange>()
    for (range in view.formattingStore.allRanges) {
      if (range.end <= selStart || range.start >= selEnd) continue

      val clippedStart = maxOf(range.start, selStart)
      val clippedEnd = minOf(range.end, selEnd)
      clippedRanges.add(
        FormattingRange(range.type, clippedStart - selStart, clippedEnd - selStart, range.url),
      )
    }

    return MarkdownSerializer.serialize(selectedText, clippedRanges)
  }

  fun copyAsMarkdown() {
    val markdown = markdownForSelectedRange() ?: return
    val clipboard = view.context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
    clipboard.setPrimaryClip(ClipData.newPlainText("Markdown", markdown))
  }

  companion object {
    private const val FORMAT_MENU_GROUP_ID = 1000
    private const val MENU_FORMAT_ID = 1001
    private const val MENU_COPY_MARKDOWN_ID = 1002
    private const val MENU_FORMAT_ITEM_BASE = 1100
    private const val CUSTOM_MENU_GROUP_ID = 2000
    private const val MENU_CUSTOM_BASE = 2001

    private val FORMAT_ITEMS =
      listOf(
        "Bold" to StyleType.BOLD,
        "Italic" to StyleType.ITALIC,
        "Underline" to StyleType.UNDERLINE,
        "Strikethrough" to StyleType.STRIKETHROUGH,
        "Spoiler" to StyleType.SPOILER,
        "Link" to StyleType.LINK,
      )
  }
}
