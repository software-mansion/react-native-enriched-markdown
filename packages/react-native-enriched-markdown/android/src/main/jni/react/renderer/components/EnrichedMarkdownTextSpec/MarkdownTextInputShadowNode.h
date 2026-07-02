#pragma once

#include "MarkdownTextInputMeasurementManager.h"
#include "MarkdownTextInputState.h"

#include <react/renderer/components/EnrichedMarkdownTextSpec/EventEmitters.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

namespace facebook::react {

JSI_EXPORT extern const char MarkdownTextInputComponentName[];

class MarkdownTextInputShadowNode final
    : public ConcreteViewShadowNode<MarkdownTextInputComponentName, EnrichedMarkdownTextInputProps,
                                    EnrichedMarkdownTextInputEventEmitter, MarkdownTextInputState> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  MarkdownTextInputShadowNode(ShadowNode const &sourceShadowNode, ShadowNodeFragment const &fragment)
      : ConcreteViewShadowNode(sourceShadowNode, fragment) {
    dirtyLayoutIfNeeded();
  }

  static ShadowNodeTraits BaseTraits() {
    // Kept as an auto-grow measuring leaf so consumers without an explicit height still grow to
    // content (measureContent measures the child editor via the synced tag); with a definite/EXACTLY
    // height the measure fills instead, and the NestedScrollView scrolls the editor inside.
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  void setMeasurementsManager(const std::shared_ptr<MarkdownTextInputMeasurementManager> &measurementsManager);

  void dirtyLayoutIfNeeded();

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints) const override;

private:
  int forceHeightRecalculationCounter_{0};
  std::shared_ptr<MarkdownTextInputMeasurementManager> measurementsManager_;
};

} // namespace facebook::react
