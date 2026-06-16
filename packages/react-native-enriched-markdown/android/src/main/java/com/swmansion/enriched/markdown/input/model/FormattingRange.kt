package com.swmansion.enriched.markdown.input.model

data class FormattingRange(
  val type: StyleType,
  var start: Int,
  var end: Int,
  var url: String? = null,
) {
  val length: Int get() = end - start
}
