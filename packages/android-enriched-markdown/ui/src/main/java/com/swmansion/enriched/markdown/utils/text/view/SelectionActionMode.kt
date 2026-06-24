package com.swmansion.enriched.markdown.utils.text.view

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.text.Spannable
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.ImageSpan

private const val MENU_ITEM_COPY_IMAGE_URL = 1001

data class SelectionMenuConfig(
  val copyImageUrl: Boolean = true,
)

fun createSelectionActionModeCallback(
  textView: TextView,
  getCustomItemTexts: () -> List<String> = { emptyList() },
  getSelectionMenuConfig: () -> SelectionMenuConfig = { SelectionMenuConfig() },
  onCustomItemPress: (itemText: String, selectedText: String, selectionStart: Int, selectionEnd: Int) -> Unit =
    { _, _, _, _ -> },
): ActionMode.Callback =
  object : ActionMode.Callback {
    override fun onCreateActionMode(
      mode: ActionMode?,
      menu: Menu?,
    ): Boolean = true

    override fun onPrepareActionMode(
      mode: ActionMode?,
      menu: Menu?,
    ): Boolean {
      if (menu == null) return false

      menu.removeItem(MENU_ITEM_COPY_IMAGE_URL)

      val selectionMenuConfig = getSelectionMenuConfig()
      val imageUrls =
        if (selectionMenuConfig.copyImageUrl) {
          textView.getImageUrlsInSelection()
        } else {
          emptyList()
        }
      if (imageUrls.isNotEmpty()) {
        val title =
          if (imageUrls.size == 1) {
            "Copy Image URL"
          } else {
            "Copy ${imageUrls.size} Image URLs"
          }
        menu.add(Menu.NONE, MENU_ITEM_COPY_IMAGE_URL, Menu.NONE, title)
      }

      return true
    }

    override fun onActionItemClicked(
      mode: ActionMode?,
      item: MenuItem?,
    ): Boolean {
      val itemId = item?.itemId ?: return false

      when (itemId) {
        android.R.id.copy -> {
          textView.copyPlainTextToClipboard()
          mode?.finish()
          return true
        }

        MENU_ITEM_COPY_IMAGE_URL -> {
          textView.copyImageUrlsToClipboard()
          mode?.finish()
          return true
        }
      }

      return false
    }

    override fun onDestroyActionMode(mode: ActionMode?) {}
  }

private fun TextView.copyPlainTextToClipboard() {
  val start = selectionStart
  val end = selectionEnd
  if (start < 0 || end < 0 || start >= end) return

  val plainText = text.subSequence(start, end).toString()
  val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
  clipboard.setPrimaryClip(ClipData.newPlainText("Text", plainText))
}

private fun TextView.getImageUrlsInSelection(): List<String> {
  val start = selectionStart
  val end = selectionEnd
  if (start < 0 || end < 0 || start >= end) return emptyList()

  val spannable = text as? Spannable ?: return emptyList()
  return spannable
    .getSpans(start, end, ImageSpan::class.java)
    .mapNotNull { it.imageUrl }
    .filter { it.startsWith("http://") || it.startsWith("https://") }
}

private fun TextView.copyImageUrlsToClipboard() {
  val urls = getImageUrlsInSelection()
  if (urls.isEmpty()) return

  val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
  clipboard.setPrimaryClip(ClipData.newPlainText("Image URLs", urls.joinToString("\n")))
}
