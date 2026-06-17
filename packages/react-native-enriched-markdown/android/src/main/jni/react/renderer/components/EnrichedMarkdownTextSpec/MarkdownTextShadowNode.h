#pragma once

#include "MarkdownTextMeasurementManager.h"

#include <react/renderer/components/EnrichedMarkdownTextSpec/EventEmitters.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

JSI_EXPORT extern const char MarkdownTextComponentName[];

/*
 * `ShadowNode` for <EnrichedMarkdownText> component.
 */
class MarkdownTextShadowNode final : public ConcreteViewShadowNode<MarkdownTextComponentName, EnrichedMarkdownTextProps,
                                                                   EnrichedMarkdownTextEventEmitter> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  // Associates a shared `MarkdownTextMeasurementManager` with the node.
  void setMeasurementsManager(const std::shared_ptr<MarkdownTextMeasurementManager> &measurementsManager);

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints) const override;

private:
  std::shared_ptr<MarkdownTextMeasurementManager> measurementsManager_;
};

} // namespace facebook::react
