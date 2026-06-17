#pragma once

#include "MarkdownContainerMeasurementManager.h"

#include <react/renderer/components/EnrichedMarkdownTextSpec/EventEmitters.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

JSI_EXPORT extern const char MarkdownContainerComponentName[];

class MarkdownContainerShadowNode final
    : public ConcreteViewShadowNode<MarkdownContainerComponentName, EnrichedMarkdownProps,
                                    EnrichedMarkdownEventEmitter> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  void setMeasurementsManager(const std::shared_ptr<MarkdownContainerMeasurementManager> &measurementsManager);

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints) const override;

private:
  std::shared_ptr<MarkdownContainerMeasurementManager> measurementsManager_;
};

} // namespace facebook::react
