package com.swmansion.enriched.markdown.utils.common

import android.text.Layout

/**
 * Resolves the break strategy for StaticLayout and TextView.
 *
 * Both Measurement (via MeasurementStore) and the render (via rendered TextView)
 * must use the same value - a mismatch causes the measured line count to differ
 * from the rendered line count, which results in the view being sized incorrectly
 * and ScrollingMovementMethod (inherited via LinkMovementMethod) silently
 * scrolling the overflow.
 *
 * When adding a lineBreakStrategy prop: read it here from props/style and apply
 * the result in both MeasurementStore (StaticLayout.Builder) and TextViewSetup
 * (TextView.breakStrategy). Both call this function, so updating it here is enough.
 *
 * Note: call sites in StaticLayout.Builder suppress "WrongConstant" lint. This is
 * intentional - Layout.BREAK_STRATEGY_SIMPLE and LineBreaker.BREAK_STRATEGY_SIMPLE
 * are the same integer (0), but the @IntDef annotation on StaticLayout.Builder
 * .setBreakStrategy() was changed from Layout.* to LineBreaker.* in API 29.
 * The suppression is safe; if this function is updated to return a LineBreaker.*
 * constant (requires API 29 guard), the suppression can be removed.
 */
fun resolveBreakStrategy(): Int = Layout.BREAK_STRATEGY_SIMPLE
