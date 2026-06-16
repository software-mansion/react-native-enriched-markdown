package com.swmansion.enriched.markdown

class EnrichedMarkdownTextLayoutManager(
  private val view: EnrichedMarkdownText,
) {
  fun invalidateLayout() {
    val text = view.text
    val paint = view.paint
    MeasurementStore.store(view.id, text, paint)
  }

  fun releaseMeasurementStore() {
    MeasurementStore.release(view.id)
  }
}
