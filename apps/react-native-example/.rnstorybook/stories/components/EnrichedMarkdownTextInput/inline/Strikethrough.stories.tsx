import React from 'react';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

export default storyMeta('Inline', 'Strikethrough');

export const Default: InputStory = {
  args: {
    initialMarkdown: '~~Strikethrough text~~ and normal text.',
  },
  render: (args) => (
    <EnrichedMarkdownTextInputStory
      title="Strikethrough"
      description="~~text~~ renders as strikethrough. The input does not expose markdownStyle for strikethrough — use the toolbar to toggle it."
      {...args}
    />
  ),
};
