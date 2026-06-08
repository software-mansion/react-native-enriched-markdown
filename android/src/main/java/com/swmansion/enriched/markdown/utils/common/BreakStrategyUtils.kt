package com.swmansion.enriched.markdown.utils.common

import android.text.Layout

/**
 * Singleton that resolves the break strategy for StaticLayout and TextView.
 *
 * Both Measurement (via MeasurementStore) and the render (via rendered TextView)
 * must use the same value - a mismatch causes the measured line count to differ
 * from the rendered line count, which results in the view being sized incorrectly
 * and ScrollingMovementMethod (inherited via LinkMovementMethod) silently
 * scrolling the overflow.
 *
 * The strategy is set from the `textBreakStrategy` prop via the view's setter,
 * which updates this object before invalidating measurement and triggering a
 * re-render. Both MeasurementStore (StaticLayout.Builder) and TextViewSetup
 * (TextView.breakStrategy) call resolveBreakStrategy(), so updating it here
 * is enough for both paths.
 *
 * Note: call sites in StaticLayout.Builder suppress "WrongConstant" lint. This is
 * intentional - Layout.BREAK_STRATEGY_SIMPLE and LineBreaker.BREAK_STRATEGY_SIMPLE
 * are the same integer (0), but the @IntDef annotation on StaticLayout.Builder
 * .setBreakStrategy() was changed from Layout.* to LineBreaker.* in API 29.
 * The suppression is safe; the Layout.* constants share the same integer values.
 */
object BreakStrategyUtils {
  private var strategy: String = "simple"

  fun setStrategy(newStrategy: String?) {
    strategy = newStrategy ?: "simple"
  }

  fun resolveBreakStrategy(): Int =
    when (strategy) {
      "highQuality" -> Layout.BREAK_STRATEGY_HIGH_QUALITY
      "balanced" -> Layout.BREAK_STRATEGY_BALANCED
      else -> Layout.BREAK_STRATEGY_SIMPLE
    }
}
