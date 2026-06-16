package com.swmansion.enriched.markdown.utils.text

import android.graphics.Bitmap
import android.util.LruCache

object ImageCache {
  private const val ORIGINAL_CACHE_SIZE = 20 * 1024 * 1024
  private const val PROCESSED_CACHE_SIZE = 30 * 1024 * 1024

  private val originalCache = bitmapLruCache(ORIGINAL_CACHE_SIZE)
  private val processedCache = bitmapLruCache(PROCESSED_CACHE_SIZE)

  fun getOriginal(url: String): Bitmap? = originalCache.get(url)

  fun putOriginal(
    url: String,
    bitmap: Bitmap,
  ) {
    originalCache.put(url, bitmap)
  }

  fun getProcessed(
    url: String,
    width: Int,
    height: Int,
    borderRadius: Int,
  ): Bitmap? = processedCache.get(processedKey(url, width, height, borderRadius))

  fun putProcessed(
    url: String,
    width: Int,
    height: Int,
    borderRadius: Int,
    bitmap: Bitmap,
  ) {
    processedCache.put(processedKey(url, width, height, borderRadius), bitmap)
  }

  private fun processedKey(
    url: String,
    width: Int,
    height: Int,
    borderRadius: Int,
  ): String = "${url}_w${width}_h${height}_r$borderRadius"

  private fun bitmapLruCache(maxSize: Int): LruCache<String, Bitmap> =
    object : LruCache<String, Bitmap>(maxSize) {
      override fun sizeOf(
        key: String,
        value: Bitmap,
      ): Int = value.byteCount
    }
}
