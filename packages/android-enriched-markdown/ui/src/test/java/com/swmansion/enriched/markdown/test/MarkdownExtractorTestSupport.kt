package com.swmansion.enriched.markdown.test

import android.text.Selection
import android.text.Spannable
import android.text.SpannableString
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor

object MarkdownExtractorTestSupport {
  fun render(document: MarkdownASTNode): SpannableString = MarkdownRenderTestSupport.render(document)

  fun createTextViewWithSelection(
    spannable: SpannableString,
    selectionStart: Int,
    selectionEnd: Int,
  ): TextView {
    val textView = TextView(ApplicationProvider.getApplicationContext())
    textView.setTextIsSelectable(true)
    textView.setText(spannable, TextView.BufferType.SPANNABLE)
    val selectableText = textView.text as Spannable
    Selection.setSelection(selectableText, selectionStart, selectionEnd)
    return textView
  }

  fun createTextViewWithSelection(
    document: MarkdownASTNode,
    selectionStart: Int,
    selectionEnd: Int,
  ): TextView = createTextViewWithSelection(render(document), selectionStart, selectionEnd)

  fun createTextViewWithFullSelection(spannable: SpannableString): TextView =
    createTextViewWithSelection(spannable, 0, spannable.length)

  fun createTextViewWithFullSelection(document: MarkdownASTNode): TextView {
    val spannable = render(document)
    return createTextViewWithFullSelection(spannable)
  }

  fun createTextViewSelectingText(
    document: MarkdownASTNode,
    selectedText: String,
  ): TextView {
    val spannable = render(document)
    val start = spannable.indexOf(selectedText)
    require(start >= 0) { "Rendered text does not contain \"$selectedText\": \"$spannable\"" }
    return createTextViewWithSelection(spannable, start, start + selectedText.length)
  }

  fun extractFromSelection(
    document: MarkdownASTNode,
    selectionStart: Int,
    selectionEnd: Int,
  ): String? {
    val textView = createTextViewWithSelection(document, selectionStart, selectionEnd)
    return MarkdownExtractor.getMarkdownForSelection(textView)
  }

  fun extractFromFullSelection(document: MarkdownASTNode): String? {
    val textView = createTextViewWithFullSelection(document)
    return MarkdownExtractor.getMarkdownForSelection(textView)
  }

  fun extractSelectingText(
    document: MarkdownASTNode,
    selectedText: String,
  ): String? {
    val textView = createTextViewSelectingText(document, selectedText)
    return MarkdownExtractor.getMarkdownForSelection(textView)
  }

  fun createEnrichedMarkdownTextWithFullSelection(
    originalMarkdown: String,
    rendered: SpannableString,
  ): EnrichedMarkdownText {
    val textView = EnrichedMarkdownText(ApplicationProvider.getApplicationContext())
    textView.setTextIsSelectable(true)
    textView.text = rendered
    setCurrentMarkdown(textView, originalMarkdown)
    val selectableText = textView.text as Spannable
    Selection.setSelection(selectableText, 0, selectableText.length)
    return textView
  }

  private fun setCurrentMarkdown(
    textView: EnrichedMarkdownText,
    markdown: String,
  ) {
    val field = EnrichedMarkdownText::class.java.getDeclaredField("currentMarkdown")
    field.isAccessible = true
    field.set(textView, markdown)
  }

  fun indexOf(spannable: Spannable, text: String): Int {
    val index = spannable.indexOf(text)
    require(index >= 0) { "Rendered text does not contain \"$text\": \"$spannable\"" }
    return index
  }
}
