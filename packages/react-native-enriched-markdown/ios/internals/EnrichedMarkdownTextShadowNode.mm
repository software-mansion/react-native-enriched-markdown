#import "EnrichedMarkdownTextShadowNode.h"
#import "EnrichedMarkdownText.h"
#import "ShadowMeasurementUtils.h"
#import <yoga/Yoga.h>

namespace facebook::react {

extern const char EnrichedMarkdownTextComponentName[] = "EnrichedMarkdownText";

EnrichedMarkdownTextShadowNode::EnrichedMarkdownTextShadowNode(const ShadowNodeFragment &fragment,
                                                               const ShadowNodeFamily::Shared &family,
                                                               ShadowNodeTraits traits)
    : ConcreteViewShadowNode(fragment, family, traits)
{
}

EnrichedMarkdownTextShadowNode::EnrichedMarkdownTextShadowNode(const ShadowNode &sourceShadowNode,
                                                               const ShadowNodeFragment &fragment)
    : ConcreteViewShadowNode(sourceShadowNode, fragment),
      localHeightRecalculationCounter_(
          static_cast<const EnrichedMarkdownTextShadowNode &>(sourceShadowNode).localHeightRecalculationCounter_),
      lastExactMeasurementCounter_(
          static_cast<const EnrichedMarkdownTextShadowNode &>(sourceShadowNode).lastExactMeasurementCounter_)
{
  const auto &oldProps = *std::static_pointer_cast<const EnrichedMarkdownTextProps>(sourceShadowNode.getProps());
  const auto &newProps = *std::static_pointer_cast<const EnrichedMarkdownTextProps>(this->getProps());

  if (newProps.streamingAnimation && ENRMPropsNeedExactStreamingMeasurement(oldProps, newProps)) {
    lastExactMeasurementCounter_ = -1;
  }

  dirtyLayoutIfNeeded();
}

void EnrichedMarkdownTextShadowNode::dirtyLayoutIfNeeded()
{
  const auto state = this->getStateData();
  const int receivedCounter = state.getHeightRecalculationCounter();

  if (receivedCounter > localHeightRecalculationCounter_) {
    localHeightRecalculationCounter_ = receivedCounter;
    YGNodeMarkDirty(&yogaNode_);
  }
}

id EnrichedMarkdownTextShadowNode::setupMockEnrichedMarkdownText_(CGFloat width) const
{
  EnrichedMarkdownText *mockView = [[EnrichedMarkdownText alloc] initWithFrame:CGRectMake(20000, 20000, width, 1000)];

  const auto props = this->getProps();
  [mockView updateProps:props oldProps:nullptr];

  const auto &typedProps = *std::static_pointer_cast<const EnrichedMarkdownTextProps>(props);
  if (!typedProps.markdown.empty()) {
    NSString *markdown = [NSString stringWithUTF8String:typedProps.markdown.c_str()];
    [mockView renderMarkdownSynchronously:markdown];
  }

  return mockView;
}

Size EnrichedMarkdownTextShadowNode::measureContent(const LayoutContext &layoutContext,
                                                    const LayoutConstraints &layoutConstraints) const
{
  const auto &typedProps = *std::static_pointer_cast<const EnrichedMarkdownTextProps>(this->getProps());
  const int receivedCounter = getStateData().getHeightRecalculationCounter();

  return ENRMMeasureMarkdownContent<EnrichedMarkdownTextProps, EnrichedMarkdownText>(
      typedProps, getStateData().getComponentViewRef(), receivedCounter, lastExactMeasurementCounter_,
      MarkdownFlavor::CommonMark, layoutConstraints,
      ^(CGFloat width) { return (EnrichedMarkdownText *)setupMockEnrichedMarkdownText_(width); });
}

} // namespace facebook::react
