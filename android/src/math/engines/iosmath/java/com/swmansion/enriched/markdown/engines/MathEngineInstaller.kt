package com.swmansion.enriched.markdown.engines

import com.swmansion.enriched.markdown.engines.iosmath.AndroidMathEngine

/**
 * AndroidMath variant of the installer. Lives in the
 * `android/src/math/engines/iosmath/` source set, which is included by
 * `build.gradle` when `enrichedMarkdown.mathEngine` is unset or
 * `androidmath` (the default).
 *
 * `EnrichedMarkdownTextPackage` calls [install] before any view manager
 * touches math content, so the registry is always populated by the time a
 * formula renders.
 */
object MathEngineInstaller {
  @Volatile
  private var installed: Boolean = false

  fun install() {
    if (installed) return
    synchronized(this) {
      if (installed) return
      MathEngineRegistry.set(AndroidMathEngine())
      installed = true
    }
  }
}
