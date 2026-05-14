package com.swmansion.enriched.markdown.engines.ratex

import android.content.Context
import android.graphics.Canvas
import com.swmansion.enriched.markdown.engines.LaidOutMath
import com.swmansion.enriched.markdown.engines.MathEngine
import io.ratex.RaTeXEngine
import io.ratex.RaTeXFontLoader
import io.ratex.RaTeXRenderer

/**
 * RaTeX-backed math engine. Selected at build time when
 * `enrichedMarkdown.mathEngine=ratex` is set in `gradle.properties`.
 *
 * RaTeX ships its Kotlin surface (`io.ratex.RaTeXEngine`, `RaTeXRenderer`,
 * `RaTeXFontLoader`) and the KaTeX TTF assets via the
 * `ratex-react-native` npm package. React Native autolinking pulls the
 * gradle module into the host app's `settings.gradle`; the parent
 * `build.gradle` adds the autolinked project as a compile-time dependency
 * when this engine is selected.
 */
class RaTeXMathEngine : MathEngine {
  override fun layout(
    context: Context,
    latex: String,
    displayMode: Boolean,
    fontSize: Float,
    color: Int,
  ): LaidOutMath? {
    if (latex.isEmpty()) return null

    RaTeXFontLoader.ensureLoaded(context, FONT_ASSET_PATH)

    return try {
      val displayList =
        RaTeXEngine.parseBlocking(
          latex = latex,
          displayMode = displayMode,
          color = color,
        )
      val renderer =
        RaTeXRenderer(displayList, fontSize) { fontId -> RaTeXFontLoader.getTypeface(fontId) }
      RaTeXLayout(renderer)
    } catch (_: Exception) {
      null
    }
  }

  companion object {
    /**
     * `ratex-react-native` packages the KaTeX TTFs under `assets/fonts/`.
     * Android's asset merger flattens autolinked modules' assets into the
     * host app, so the same path resolves once the package is installed.
     */
    private const val FONT_ASSET_PATH = "fonts"
  }
}

private class RaTeXLayout(
  private val renderer: RaTeXRenderer,
) : LaidOutMath {
  override val widthPx: Float get() = renderer.widthPx
  override val ascentPx: Float get() = renderer.heightPx
  override val descentPx: Float get() = renderer.depthPx

  override fun drawOn(canvas: Canvas) {
    renderer.draw(canvas)
  }
}

