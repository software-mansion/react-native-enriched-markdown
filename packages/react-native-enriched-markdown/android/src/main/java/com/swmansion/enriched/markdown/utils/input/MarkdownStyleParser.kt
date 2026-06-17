package com.swmansion.enriched.markdown.utils.input

import com.facebook.react.bridge.ReadableMap
import com.swmansion.enriched.markdown.input.model.InputFormatterStyle
import com.swmansion.enriched.markdown.input.model.InputLinkVariantStyle

object MarkdownStyleParser {
  fun parse(map: ReadableMap): InputFormatterStyle {
    val strongMap = map.getMap("strong")
    val emMap = map.getMap("em")
    val linkMap = map.getMap("link")
    val spoilerMap = map.getMap("spoiler")

    return InputFormatterStyle(
      boldColor = if (strongMap?.hasKey("color") == true) strongMap.getInt("color") else null,
      italicColor = if (emMap?.hasKey("color") == true) emMap.getInt("color") else null,
      linkColor = linkMap!!.getInt("color"),
      linkUnderline = linkMap.getBoolean("underline"),
      linkBackgroundColor = linkMap.getInt("backgroundColor"),
      linkVariants = parseLinkVariants(map),
      spoilerColor = spoilerMap!!.getInt("color"),
      spoilerBackgroundColor = spoilerMap.getInt("backgroundColor"),
    )
  }

  private fun parseLinkVariants(map: ReadableMap): List<InputLinkVariantStyle> {
    if (!map.hasKey("linkVariants")) return emptyList()
    val variants = map.getArray("linkVariants") ?: return emptyList()
    return (0 until variants.size()).mapNotNull { index ->
      val variant = variants.getMap(index) ?: return@mapNotNull null
      InputLinkVariantStyle(
        pattern = variant.getString("pattern") ?: return@mapNotNull null,
        color = variant.getInt("color"),
        underline = variant.getBoolean("underline"),
        backgroundColor = variant.getInt("backgroundColor"),
      )
    }
  }
}
