package com.swmansion.enriched.markdown.engines

import android.content.Context
import android.graphics.Canvas

/**
 * Result of laying out a single LaTeX formula. Engines hand one of these back
 * to [com.swmansion.enriched.markdown.spans.MathInlineSpan] /
 * [com.swmansion.enriched.markdown.views.MathContainerView], which use the
 * geometry numbers to size the host span / view and [drawOn] to paint the
 * glyphs.
 */
interface LaidOutMath {
  /** Total width in pixels. */
  val widthPx: Float

  /** Ascent above the baseline in pixels. */
  val ascentPx: Float

  /** Descent below the baseline in pixels. */
  val descentPx: Float

  /** Total height in pixels (ascent + descent). */
  val totalHeightPx: Float get() = ascentPx + descentPx

  /**
   * Draw the formula into [canvas] with origin (0, 0) at the top-left of the
   * formula's bounding box (Android-native — Y increases downward).
   */
  fun drawOn(canvas: Canvas)
}

/**
 * Parses and lays out a LaTeX string. Returns `null` when the engine cannot
 * render the input — callers fall back to a zero-width span / empty view so
 * the surrounding text still lays out cleanly.
 */
interface MathEngine {
  fun layout(
    context: Context,
    latex: String,
    displayMode: Boolean,
    fontSize: Float,
    color: Int,
  ): LaidOutMath?
}

/**
 * Process-wide engine accessor. The build wires this to the engine selected
 * via the `enrichedMarkdown.mathEngine` Gradle property — by default the
 * AndroidMath-backed engine, optionally RaTeX. Only one engine ships in the
 * binary; the other source set is excluded by `build.gradle`.
 */
object MathEngineRegistry {
  @Volatile
  private var engine: MathEngine? = null

  fun set(engine: MathEngine) {
    this.engine = engine
  }

  fun get(): MathEngine =
    engine
      ?: error(
        "MathEngine has not been registered. Each engine source set installs " +
          "itself via its own EngineInstaller — make sure the build includes " +
          "one of android/src/math/engines/{androidmath,ratex}/java.",
      )
}
