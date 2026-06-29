package com.swmansion.enriched.markdown.test

import android.content.Context
import android.text.SpannableString
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig

object MarkdownRenderTestSupport {
  private val context: Context = ApplicationProvider.getApplicationContext()

  fun render(document: MarkdownASTNode): SpannableString {
    val renderer = Renderer()
    renderer.configure(StyleConfig.default(context), context)
    return renderer.renderDocument(document, null, null)
  }
}
