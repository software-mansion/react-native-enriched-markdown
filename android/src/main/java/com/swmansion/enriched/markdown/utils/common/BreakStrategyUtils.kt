package com.swmansion.enriched.markdown.utils.common

import android.text.Layout

/**
 * Resolves the break strategy for StaticLayout and TextView.
 *
 * Both MeasurementStore and the rendered TextView must use the same value —
 * a mismatch causes the measured line count to differ from the rendered line
 * count, which results in the view being sized incorrectly and ScrollingMovementMethod
 * (inherited via LinkMovementMethod) silently scrolling the overflow.
 *
 * When adding a lineBreakStrategy prop: read it here from props/style and apply
 * the result in both MeasurementStore (StaticLayout.Builder) and TextViewSetup
 * (TextView.breakStrategy). Both call this function, so updating it here is enough.
 */
fun resolveBreakStrategy(): Int = Layout.BREAK_STRATEGY_SIMPLE
