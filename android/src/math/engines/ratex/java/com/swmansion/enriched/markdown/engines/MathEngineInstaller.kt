package com.swmansion.enriched.markdown.engines

import com.swmansion.enriched.markdown.engines.ratex.RaTeXMathEngine

/**
 * RaTeX variant of the installer. Lives in the
 * `android/src/math/engines/ratex/` source set, which is included by
 * `build.gradle` only when `enrichedMarkdown.mathEngine=ratex` is set in
 * `gradle.properties`.
 */
object MathEngineInstaller {
  @Volatile
  private var installed: Boolean = false

  fun install() {
    if (installed) return
    synchronized(this) {
      if (installed) return
      MathEngineRegistry.set(RaTeXMathEngine())
      installed = true
    }
  }
}
