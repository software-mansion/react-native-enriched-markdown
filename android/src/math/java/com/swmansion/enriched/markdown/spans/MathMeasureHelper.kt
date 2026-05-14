package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import com.swmansion.enriched.markdown.engines.MathEngineRegistry
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Synchronous formula measurement used by the shadow tree to size math rows
 * before the spans are constructed on the UI thread.
 *
 * Delegates to the active [com.swmansion.enriched.markdown.engines.MathEngine].
 * Some engines (AndroidMath) need to touch view-system primitives that are
 * main-thread only, so we keep the main-thread bounce + timeout that the
 * previous AndroidMath-specific helper used; engines that are thread-safe
 * (RaTeX) still benefit from the per-request error isolation.
 */
object MathMeasureHelper {
  private const val BASE_TIMEOUT_MS = 500L
  private const val PER_ITEM_TIMEOUT_MS = 50L
  private val mainHandler = Handler(Looper.getMainLooper())

  @JvmStatic
  fun measureOnMainThread(
    context: Context,
    requests: List<MathMeasureRequest>,
  ): List<MathMetrics> {
    if (requests.isEmpty()) return emptyList()

    if (Looper.myLooper() == Looper.getMainLooper()) {
      return requests.map { measureSingle(context, it) }
    }

    val results = mutableListOf<MathMetrics?>()
    val latch = CountDownLatch(1)
    val timeout = BASE_TIMEOUT_MS + (PER_ITEM_TIMEOUT_MS * requests.size)

    mainHandler.post {
      requests.mapTo(results) { request ->
        runCatching { measureSingle(context, request) }.getOrNull()
      }
      latch.countDown()
    }

    val completed = latch.await(timeout, TimeUnit.MILLISECONDS)

    return requests.mapIndexed { i, req ->
      if (completed) {
        results.getOrNull(i) ?: estimateFallback(req)
      } else {
        estimateFallback(req)
      }
    }
  }

  private fun measureSingle(
    context: Context,
    request: MathMeasureRequest,
  ): MathMetrics {
    val engine = MathEngineRegistry.get()
    val displayMode = request.mode == MathRenderMode.Display
    val layout =
      engine.layout(
        context = context,
        latex = request.latex,
        displayMode = displayMode,
        fontSize = request.fontSize,
        // Color doesn't affect measurement; use opaque black as a safe default.
        color = Color.BLACK,
      ) ?: return estimateFallback(request)

    return MathMetrics(
      width =
        kotlin.math
          .ceil(layout.widthPx)
          .toInt()
          .coerceAtLeast(1),
      ascent = layout.ascentPx,
      descent = layout.descentPx,
    )
  }

  private fun estimateFallback(request: MathMeasureRequest): MathMetrics {
    val h = request.fontSize * 1.4f
    return MathMetrics(
      width =
        (request.fontSize * request.latex.length * 0.5f)
          .coerceIn(request.fontSize, request.fontSize * 20f)
          .toInt(),
      ascent = h * 0.7f,
      descent = h * 0.3f,
    )
  }
}
