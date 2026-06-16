package com.swmansion.enriched.markdown.styles

import com.facebook.react.bridge.ReadableMap

data class ImageStyle(
  val height: Float,
  val borderRadius: Float,
  val marginTop: Float,
  val marginBottom: Float,
) {
  companion object {
    fun fromReadableMap(
      map: ReadableMap,
      parser: StyleParser,
    ): ImageStyle {
      val height = parser.toPixelFromDIP(map.getDouble("height").toFloat())
      val borderRadius = parser.toPixelFromDIP(map.getDouble("borderRadius").toFloat())
      val marginTop = parser.toPixelFromDIP(map.getDouble("marginTop").toFloat())
      val marginBottom = parser.toPixelFromDIP(map.getDouble("marginBottom").toFloat())
      return ImageStyle(height, borderRadius, marginTop, marginBottom)
    }
  }
}
