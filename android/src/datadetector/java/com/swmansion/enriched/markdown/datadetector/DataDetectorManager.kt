package com.swmansion.enriched.markdown.datadetector

import android.util.Log
import com.google.mlkit.nl.entityextraction.Entity
import com.google.mlkit.nl.entityextraction.EntityAnnotation
import com.google.mlkit.nl.entityextraction.EntityExtraction
import com.google.mlkit.nl.entityextraction.EntityExtractionParams
import com.google.mlkit.nl.entityextraction.EntityExtractorOptions
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

data class DetectedEntity(
  val type: String,
  val text: String,
  val url: String,
  val dataJson: String,
  val start: Int,
  val end: Int,
)

/**
 * Stateless utility that performs ML Kit entity extraction.
 * Each [detect] call creates a fresh EntityExtractor client, downloads the model
 * if needed, runs annotation, and closes the client — mirroring the approach used
 * by react-native-data-detector to avoid stale-client issues.
 */
object DataDetectorManager {
  private const val TAG = "DataDetectorManager"
  private const val TIMEOUT_SECONDS = 15L

  fun detect(
    text: String,
    types: Set<String>,
    language: String = "en",
  ): List<DetectedEntity> {
    if (text.isBlank() || types.isEmpty()) return emptyList()

    val modelId = modelIdentifierFor(language)
    val options = EntityExtractorOptions.Builder(modelId).build()
    val extractor = EntityExtraction.getClient(options)

    try {
      val downloadLatch = CountDownLatch(1)
      val downloadError = AtomicReference<Exception?>(null)

      extractor
        .downloadModelIfNeeded()
        .addOnSuccessListener { downloadLatch.countDown() }
        .addOnFailureListener { e ->
          downloadError.set(e)
          downloadLatch.countDown()
        }

      if (!downloadLatch.await(TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
        Log.w(TAG, "Model download timed out for language: $language")
        return emptyList()
      }

      downloadError.get()?.let { e ->
        Log.w(TAG, "Model download failed: ${e.message}")
        return emptyList()
      }

      val params = EntityExtractionParams.Builder(text).build()
      val annotateLatch = CountDownLatch(1)
      val annotateResult = AtomicReference<List<EntityAnnotation>?>(null)
      val annotateError = AtomicReference<Exception?>(null)

      extractor
        .annotate(params)
        .addOnSuccessListener { result ->
          annotateResult.set(result)
          annotateLatch.countDown()
        }.addOnFailureListener { e ->
          annotateError.set(e)
          annotateLatch.countDown()
        }

      if (!annotateLatch.await(TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
        Log.w(TAG, "Annotation timed out")
        return emptyList()
      }

      annotateError.get()?.let { e ->
        Log.w(TAG, "Annotation failed: ${e.message}")
        return emptyList()
      }

      val annotations = annotateResult.get() ?: return emptyList()
      val entityTypes = mapTypesToEntityTypes(types)

      return annotations
        .flatMap { annotation ->
          annotation.entities
            .filter { entity -> entityTypes.contains(entity.type) }
            .map { entity ->
              val matchedText = text.substring(annotation.start, annotation.end)
              DetectedEntity(
                type = entityTypeToString(entity.type),
                text = matchedText,
                url = buildUrlForEntity(entity, matchedText),
                dataJson = buildDataJsonForEntity(entity, matchedText),
                start = annotation.start,
                end = annotation.end,
              )
            }
        }.distinctBy { it.start to it.end }
    } catch (e: Exception) {
      Log.w(TAG, "Detection failed unexpectedly: ${e.message}", e)
      return emptyList()
    } finally {
      extractor.close()
    }
  }

  private fun modelIdentifierFor(language: String): String =
    when (language) {
      "ar" -> EntityExtractorOptions.ARABIC
      "nl" -> EntityExtractorOptions.DUTCH
      "en" -> EntityExtractorOptions.ENGLISH
      "fr" -> EntityExtractorOptions.FRENCH
      "de" -> EntityExtractorOptions.GERMAN
      "it" -> EntityExtractorOptions.ITALIAN
      "ja" -> EntityExtractorOptions.JAPANESE
      "ko" -> EntityExtractorOptions.KOREAN
      "pl" -> EntityExtractorOptions.POLISH
      "pt" -> EntityExtractorOptions.PORTUGUESE
      "ru" -> EntityExtractorOptions.RUSSIAN
      "es" -> EntityExtractorOptions.SPANISH
      "th" -> EntityExtractorOptions.THAI
      "tr" -> EntityExtractorOptions.TURKISH
      "zh" -> EntityExtractorOptions.CHINESE
      else -> EntityExtractorOptions.ENGLISH
    }

  private fun mapTypesToEntityTypes(types: Set<String>): Set<Int> {
    val entityTypes = mutableSetOf<Int>()
    for (type in types) {
      when (type) {
        "phoneNumber" -> entityTypes.add(Entity.TYPE_PHONE)
        "link" -> entityTypes.add(Entity.TYPE_URL)
        "email" -> entityTypes.add(Entity.TYPE_EMAIL)
        "address" -> entityTypes.add(Entity.TYPE_ADDRESS)
        "date" -> entityTypes.add(Entity.TYPE_DATE_TIME)
      }
    }
    return entityTypes
  }

  private fun entityTypeToString(type: Int): String =
    when (type) {
      Entity.TYPE_PHONE -> "phoneNumber"
      Entity.TYPE_URL -> "link"
      Entity.TYPE_EMAIL -> "email"
      Entity.TYPE_ADDRESS -> "address"
      Entity.TYPE_DATE_TIME -> "date"
      else -> "link"
    }

  private fun buildUrlForEntity(
    entity: Entity,
    matchedText: String,
  ): String =
    when (entity.type) {
      Entity.TYPE_PHONE -> {
        "tel:$matchedText"
      }

      Entity.TYPE_URL -> {
        if (matchedText.startsWith("http://") || matchedText.startsWith("https://")) {
          matchedText
        } else {
          "https://$matchedText"
        }
      }

      Entity.TYPE_EMAIL -> {
        "mailto:$matchedText"
      }

      Entity.TYPE_ADDRESS -> {
        matchedText
      }

      Entity.TYPE_DATE_TIME -> {
        matchedText
      }

      else -> {
        matchedText
      }
    }

  private fun buildDataJsonForEntity(
    entity: Entity,
    matchedText: String,
  ): String {
    val json = JSONObject()
    when (entity.type) {
      Entity.TYPE_PHONE -> json.put("phoneNumber", matchedText)
      Entity.TYPE_URL -> json.put("url", matchedText)
      Entity.TYPE_EMAIL -> json.put("email", matchedText)
      Entity.TYPE_ADDRESS -> json.put("address", matchedText)
      Entity.TYPE_DATE_TIME -> json.put("date", matchedText)
    }
    return json.toString()
  }
}
