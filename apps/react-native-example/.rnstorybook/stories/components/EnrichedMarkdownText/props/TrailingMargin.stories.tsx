import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type TrailingMarginStoryExtra = {
  allowTrailingMargin: boolean;
};

const MARKDOWN = `First paragraph with bottom margin.

Second paragraph — compare spacing below the last line.`;

const argTypes = {
  allowTrailingMargin: {
    control: 'boolean',
    description:
      'When true, keeps marginBottom on the last block. When false (default), trims trailing spacing.',
  },
};

export default storyMeta('Props', 'Trailing Margin');

export const Default: TextStory<TrailingMarginStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    allowTrailingMargin: false,
  },
  argTypes,
  render: ({ allowTrailingMargin, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Trailing Margin"
      description="allowTrailingMargin controls whether the last block keeps its marginBottom. Paragraph marginBottom is fixed at 24px for comparison."
      {...args}
      allowTrailingMargin={allowTrailingMargin}
      style={{
        paragraph: { marginBottom: 24 },
      }}
    />
  ),
};
