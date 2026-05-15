package com.swmansion.enriched.markdown.renderer

import android.graphics.Typeface
import com.swmansion.enriched.markdown.styles.LinkVariantEntry
import com.swmansion.enriched.markdown.styles.StyleConfig

/** Shared style cache for spans to avoid redundant calculations. */
class SpanStyleCache(
  style: StyleConfig,
) {
  // Colors to preserve when applying inline styles (links, code, strong, emphasis)
  val colorsToPreserve: IntArray = buildColorsToPreserve(style)

  val strongFontFamily: String = style.strongStyle.fontFamily
  val strongFontWeight: String = style.strongStyle.fontWeight
  val strongColor: Int? = style.strongStyle.color
  val emphasisFontFamily: String = style.emphasisStyle.fontFamily
  val emphasisFontStyle: String = style.emphasisStyle.fontStyle
  val emphasisColor: Int? = style.emphasisStyle.color
  val strikethroughColor: Int = style.strikethroughStyle.color
  val linkFontFamily: String = style.linkStyle.fontFamily
  val linkColor: Int = style.linkStyle.color
  val linkUnderline: Boolean = style.linkStyle.underline
  val linkBackgroundColor: Int = style.linkStyle.backgroundColor
  val linkVariants: List<LinkVariantEntry> = style.linkVariants

  private val compiledVariantPatterns: List<Pair<Regex, LinkVariantEntry>> =
    linkVariants.mapNotNull { entry ->
      try {
        Regex(entry.pattern) to entry
      } catch (_: Exception) {
        null
      }
    }

  val codeFontFamily: String = style.codeStyle.fontFamily
  val codeFontSize: Float = style.codeStyle.fontSize
  val codeColor: Int = style.codeStyle.color
  val spoilerColor: Int = style.spoilerStyle.color
  val spoilerParticleDensity: Float = style.spoilerStyle.particleDensity
  val spoilerParticleSpeed: Float = style.spoilerStyle.particleSpeed
  val spoilerSolidBorderRadius: Float = style.spoilerStyle.solidBorderRadius
  val superscriptFontScale: Float = style.superscriptStyle.fontScale
  val superscriptBaselineOffsetScale: Float = style.superscriptStyle.baselineOffsetScale
  val subscriptFontScale: Float = style.subscriptStyle.fontScale
  val subscriptBaselineOffsetScale: Float = style.subscriptStyle.baselineOffsetScale

  private fun buildColorsToPreserve(style: StyleConfig): IntArray {
    val paragraphColor = style.paragraphStyle.color
    return buildList {
      style.strongStyle.color
        ?.takeIf { it != 0 }
        ?.let { add(it) }
      style.emphasisStyle.color
        ?.takeIf { it != 0 }
        ?.let { add(it) }
      style.linkStyle.color
        .takeIf { it != 0 && it != paragraphColor }
        ?.let { add(it) }
      style.linkVariants.forEach { variant ->
        variant.color
          .takeIf { it != 0 && it != paragraphColor }
          ?.let { add(it) }
      }
      style
        .codeStyle
        .color
        .takeIf { it != 0 }
        ?.let { add(it) }
      style.taskListStyle.checkedTextColor
        .takeIf { it != 0 }
        ?.let { add(it) }
    }.toIntArray()
  }

  fun getStrongColorFor(blockColor: Int): Int = strongColor ?: blockColor

  fun getEmphasisColorFor(
    blockColor: Int,
    currentColor: Int,
  ): Int =
    if (currentColor == blockColor) {
      emphasisColor ?: blockColor
    } else {
      currentColor
    }

  fun resolvedVariantForUrl(url: String): LinkVariantEntry? {
    if (compiledVariantPatterns.isEmpty()) return null
    return compiledVariantPatterns.firstOrNull { (regex, _) -> regex.containsMatchIn(url) }?.second
  }

  companion object {
    private val typefaceCache = mutableMapOf<String, Typeface>()

    /** Cached typeface for font family + style (BOLD, ITALIC, BOLD_ITALIC) */
    fun getTypeface(
      fontFamily: String,
      style: Int,
    ): Typeface =
      typefaceCache.getOrPut("$fontFamily|$style") {
        val base =
          fontFamily
            .takeIf { it.isNotEmpty() }
            ?.let { Typeface.create(it, Typeface.NORMAL) }
            ?: Typeface.DEFAULT
        Typeface.create(base, style)
      }

    /** Cached typeface using weight string (e.g., "bold", "700") */
    fun getTypefaceWithWeight(
      fontFamily: String,
      fontWeight: String,
    ): Typeface {
      val style =
        when (fontWeight.lowercase()) {
          "bold", "700", "800", "900" -> Typeface.BOLD
          else -> Typeface.NORMAL
        }
      return getTypeface(fontFamily, style)
    }

    /** Cached monospace typeface preserving bold/italic */
    fun getMonospaceTypeface(currentStyle: Int): Typeface =
      typefaceCache.getOrPut("monospace|$currentStyle") {
        Typeface.create(Typeface.MONOSPACE, currentStyle)
      }
  }
}
