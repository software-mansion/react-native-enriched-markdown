#pragma once

#include <folly/dynamic.h>

namespace facebook::react {

// Shared by <EnrichedMarkdownText> and <EnrichedMarkdown>: the Android view
// bumps the counter when rendered content height changes after measurement
// (e.g. a block image resolves its box height once the bitmap loads).
class MarkdownTextState {
public:
  MarkdownTextState() : forceHeightRecalculationCounter_(0) {}

  MarkdownTextState(MarkdownTextState const &previousState, folly::dynamic data)
      : forceHeightRecalculationCounter_((int)data["forceHeightRecalculationCounter"].getInt()) {}

  folly::dynamic getDynamic() const {
    return {};
  }

  int getForceHeightRecalculationCounter() const;

private:
  const int forceHeightRecalculationCounter_{};
};

} // namespace facebook::react
