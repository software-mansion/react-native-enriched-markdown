package com.swmansion.enriched.markdown.input.autolink

data class LinkRegexConfig(
  val pattern: String,
  val caseInsensitive: Boolean,
  val dotAll: Boolean,
  val isDisabled: Boolean,
  val isDefault: Boolean,
)
