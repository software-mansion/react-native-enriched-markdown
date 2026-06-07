import React from 'react';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

export default storyMeta('Inline', 'Underline');

export const Default: InputStory = {
  args: {
    initialMarkdown: '_Underlined text_ and normal text.',
  },
  render: (args) => (
    <EnrichedMarkdownTextInputStory
      title="Underline"
      description="_text_ renders as underline. The input does not expose markdownStyle for underline — use the toolbar to toggle it."
      {...args}
    />
  ),
};
