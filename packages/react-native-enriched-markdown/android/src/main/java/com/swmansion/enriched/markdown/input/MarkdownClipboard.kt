package com.swmansion.enriched.markdown.input

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context

/**
 * Clipboard round-trip for markdown content, mirroring iOS's
 * kENRMMarkdownPasteboardType: clips created here carry a vendor MIME type so
 * paste can distinguish our markdown from arbitrary external text (which keeps
 * pasting as plain text).
 */
object MarkdownClipboard {
  const val MIME_TYPE = "text/vnd.swmansion.enriched-markdown"

  fun newMarkdownClip(markdown: String): ClipData =
    ClipData(
      ClipDescription("Markdown", arrayOf(MIME_TYPE, ClipDescription.MIMETYPE_TEXT_PLAIN)),
      ClipData.Item(markdown),
    )

  /** Returns the clipboard's markdown, or null if the clip wasn't created by [newMarkdownClip]. */
  fun markdownFromClipboard(context: Context): String? {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return null
    val clip = clipboard.primaryClip ?: return null
    if (!clip.description.hasMimeType(MIME_TYPE)) return null
    if (clip.itemCount == 0) return null
    return clip
      .getItemAt(0)
      .text
      ?.toString()
      ?.takeIf { it.isNotEmpty() }
  }
}
