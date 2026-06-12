package com.swmansion.enriched.markdown.utils.common

import com.swmansion.enriched.markdown.BuildConfig

object FeatureFlags {
  const val IS_MATH_ENABLED: Boolean = BuildConfig.ENABLE_MATH
  const val IS_DATA_DETECTOR_ENABLED: Boolean = BuildConfig.ENABLE_DATA_DETECTOR
}
