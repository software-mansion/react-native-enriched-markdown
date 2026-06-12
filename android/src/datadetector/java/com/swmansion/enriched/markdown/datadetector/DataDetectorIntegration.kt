package com.swmansion.enriched.markdown.datadetector

import android.content.Context
import android.text.Spannable
import android.text.style.ClickableSpan
import android.util.Log
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache

/**
 * Integration bridge between the main source set and the ML Kit-based data detector.
 * This class is only compiled when `enrichedMarkdown.enableDataDetector=true`.
 */
object DataDetectorIntegration {
  private const val TAG = "DataDetectorIntegration"

  fun applyDataDetection(
    spannable: Spannable,
    types: Set<String>,
    language: String,
    styleCache: SpanStyleCache,
    blockStyle: BlockStyle,
    context: Context,
  ) {
    if (types.isEmpty() || spannable.isEmpty()) return

    val plainText = spannable.toString()

    val detectedEntities =
      try {
        DataDetectorManager.detect(plainText, types, language)
      } catch (e: Exception) {
        Log.w(TAG, "Data detection failed: ${e.message}")
        return
      }

    for (entity in detectedEntities) {
      if (entity.start < 0 || entity.end > spannable.length) continue

      val existingSpans = spannable.getSpans(entity.start, entity.end, ClickableSpan::class.java)
      val hasOverlap =
        existingSpans.any { span ->
          val spanStart = spannable.getSpanStart(span)
          val spanEnd = spannable.getSpanEnd(span)
          spanStart < entity.end && spanEnd > entity.start
        }
      if (hasOverlap) continue

      val span =
        DataDetectorSpan(
          entityType = entity.type,
          matchedText = entity.text,
          url = entity.url,
          dataJson = entity.dataJson,
          styleCache = styleCache,
          blockStyle = blockStyle,
          context = context,
        )

      spannable.setSpan(span, entity.start, entity.end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
  }
}
