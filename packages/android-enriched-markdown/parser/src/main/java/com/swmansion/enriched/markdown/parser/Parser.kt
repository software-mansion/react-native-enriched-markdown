package com.swmansion.enriched.markdown.parser

class Parser {
  companion object {
    init {
      System.loadLibrary("enriched_markdown_parser")
    }

    @JvmStatic
    private external fun nativeParseNodeCount(markdown: String): Int
  }

  fun parseNodeCount(markdown: String): Int = nativeParseNodeCount(markdown)
}
