package com.swmansion.enriched.markdown.input.model

data class InputFormatterStyle(
  val boldColor: Int?,
  val italicColor: Int?,
  val linkColor: Int,
  val linkUnderline: Boolean,
  val linkBackgroundColor: Int,
  val linkVariants: List<InputLinkVariantStyle>,
  val spoilerColor: Int,
  val spoilerBackgroundColor: Int,
)

data class InputLinkVariantStyle(
  val pattern: String,
  val color: Int,
  val underline: Boolean,
  val backgroundColor: Int,
) {
  val compiledRegex: Regex? =
    try {
      Regex(pattern)
    } catch (_: Exception) {
      null
    }
}
