#import "EnrichedMarkdownShadowNode.h"
#import "EnrichedMarkdown.h"
#import "ShadowMeasurementUtils.h"
#import <yoga/Yoga.h>

namespace facebook::react {

extern const char EnrichedMarkdownComponentName[] = "EnrichedMarkdown";

EnrichedMarkdownShadowNode::EnrichedMarkdownShadowNode(const ShadowNodeFragment &fragment,
                                                       const ShadowNodeFamily::Shared &family, ShadowNodeTraits traits)
    : ConcreteViewShadowNode(fragment, family, traits)
{
}

EnrichedMarkdownShadowNode::EnrichedMarkdownShadowNode(const ShadowNode &sourceShadowNode,
                                                       const ShadowNodeFragment &fragment)
    : ConcreteViewShadowNode(sourceShadowNode, fragment),
      localHeightRecalculationCounter_(
          static_cast<const EnrichedMarkdownShadowNode &>(sourceShadowNode).localHeightRecalculationCounter_),
      lastExactMeasurementCounter_(
          static_cast<const EnrichedMarkdownShadowNode &>(sourceShadowNode).lastExactMeasurementCounter_)
{
  const auto &oldProps = *std::static_pointer_cast<const EnrichedMarkdownProps>(sourceShadowNode.getProps());
  const auto &newProps = *std::static_pointer_cast<const EnrichedMarkdownProps>(this->getProps());

  if (newProps.streamingAnimation && ENRMPropsNeedExactStreamingMeasurement(oldProps, newProps)) {
    lastExactMeasurementCounter_ = -1;
  }

  dirtyLayoutIfNeeded();
}

void EnrichedMarkdownShadowNode::dirtyLayoutIfNeeded()
{
  const auto state = this->getStateData();
  const int receivedCounter = state.getHeightRecalculationCounter();

  if (receivedCounter > localHeightRecalculationCounter_) {
    localHeightRecalculationCounter_ = receivedCounter;
    YGNodeMarkDirty(&yogaNode_);
  }
}

id EnrichedMarkdownShadowNode::setupMockEnrichedMarkdown_(CGFloat width) const
{
  EnrichedMarkdown *mockView = [[EnrichedMarkdown alloc] initWithFrame:CGRectMake(20000, 20000, width, 1000)];

  const auto props = this->getProps();
  [mockView updateProps:props oldProps:nullptr];

  const auto &typedProps = *std::static_pointer_cast<const EnrichedMarkdownProps>(props);
  if (!typedProps.markdown.empty()) {
    NSString *markdown = [NSString stringWithUTF8String:typedProps.markdown.c_str()];
    [mockView renderMarkdownSynchronously:markdown];
  }

  return mockView;
}

Size EnrichedMarkdownShadowNode::measureContent(const LayoutContext &layoutContext,
                                                const LayoutConstraints &layoutConstraints) const
{
  const auto &typedProps = *std::static_pointer_cast<const EnrichedMarkdownProps>(this->getProps());
  const int receivedCounter = getStateData().getHeightRecalculationCounter();

  return ENRMMeasureMarkdownContent<EnrichedMarkdownProps, EnrichedMarkdown>(
      typedProps, getStateData().getComponentViewRef(), receivedCounter, lastExactMeasurementCounter_,
      MarkdownFlavor::GitHub, layoutConstraints,
      ^(CGFloat width) { return (EnrichedMarkdown *)setupMockEnrichedMarkdown_(width); });
}

} // namespace facebook::react
