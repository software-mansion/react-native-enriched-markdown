#include "MarkdownContainerShadowNode.h"

#include <react/renderer/core/LayoutContext.h>

namespace facebook::react {

extern const char MarkdownContainerComponentName[] = "EnrichedMarkdown";

void MarkdownContainerShadowNode::setMeasurementsManager(
    const std::shared_ptr<MarkdownContainerMeasurementManager> &measurementsManager) {
  ensureUnsealed();
  measurementsManager_ = measurementsManager;
}

Size MarkdownContainerShadowNode::measureContent(const LayoutContext &layoutContext,
                                                 const LayoutConstraints &layoutConstraints) const {
  return measurementsManager_->measure(getSurfaceId(), getTag(), getConcreteProps(), layoutConstraints);
}

} // namespace facebook::react
