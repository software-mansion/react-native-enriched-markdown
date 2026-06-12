package com.swmansion.enriched.markdown.datadetector

import android.content.Context
import android.text.Spannable
import android.util.Log
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.utils.common.FeatureFlags

/**
 * Provider that conditionally delegates to the ML Kit-based DataDetectorIntegration
 * when the feature is enabled at compile time. When disabled, all methods are no-ops.
 */
object DataDetectorProvider {
  private const val TAG = "DataDetectorProvider"

  fun applyDataDetection(
    spannable: Spannable,
    types: Set<String>,
    language: String,
    styleCache: SpanStyleCache,
    blockStyle: BlockStyle,
    context: Context,
  ) {
    if (!FeatureFlags.IS_DATA_DETECTOR_ENABLED || types.isEmpty()) return

    try {
      val integrationClass =
        Class.forName(
          "com.swmansion.enriched.markdown.datadetector.DataDetectorIntegration",
        )
      val method =
        integrationClass.getMethod(
          "applyDataDetection",
          Spannable::class.java,
          Set::class.java,
          String::class.java,
          SpanStyleCache::class.java,
          BlockStyle::class.java,
          Context::class.java,
        )
      method.invoke(
        integrationClass.getField("INSTANCE").get(null),
        spannable,
        types,
        language,
        styleCache,
        blockStyle,
        context,
      )
    } catch (e: ClassNotFoundException) {
      Log.w(TAG, "DataDetectorIntegration class not found — feature not compiled in")
    } catch (e: Exception) {
      Log.e(TAG, "Data detection reflection error: ${e.message}", e)
    }
  }
}
