package com.swmansion.enriched.markdown

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager
import com.swmansion.enriched.markdown.input.EnrichedMarkdownTextInputManager
import com.swmansion.enriched.markdown.utils.common.FeatureFlags
import java.util.ArrayList

class EnrichedMarkdownTextPackage : ReactPackage {
  init {
    // Install the math engine selected at build time (AndroidMath by default,
    // RaTeX when `enrichedMarkdown.mathEngine=ratex`). The installer lives in
    // the engine-specific source set picked by `build.gradle`, so reflection
    // is used so the main source set doesn't depend on either engine.
    if (FeatureFlags.isMathEnabled) {
      runCatching {
        val installer = Class.forName("com.swmansion.enriched.markdown.engines.MathEngineInstaller")
        installer.getMethod("install").invoke(installer.getField("INSTANCE").get(null))
      }
    }
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
    val viewManagers: MutableList<ViewManager<*, *>> = ArrayList()
    viewManagers.add(EnrichedMarkdownTextManager())
    viewManagers.add(EnrichedMarkdownManager())
    viewManagers.add(EnrichedMarkdownTextInputManager())
    return viewManagers
  }

  override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> = emptyList()
}
