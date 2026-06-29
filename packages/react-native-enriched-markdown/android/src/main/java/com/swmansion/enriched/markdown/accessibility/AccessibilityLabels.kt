package com.swmansion.enriched.markdown.accessibility

data class AccessibilityLabels(
  val bulletPoint: String = "Bullet point",
  val nestedBulletPoint: String = "Nested bullet point",
  val orderedItem: String = "List item {n}",
  val nestedOrderedItem: String = "Nested list item {n}",
  val tableRow: String = "Row {n}: {content}",
  val mathEquation: String = "Math: {latex}",
  val rotorHeadings: String = "Headings",
  val rotorLinks: String = "Links",
  val rotorImages: String = "Images",
)
