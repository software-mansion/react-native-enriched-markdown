import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type SelectionMenuStoryExtra = {
  copyAsMarkdown: boolean;
  copyImageUrl: boolean;
};

const MARKDOWN = `Select this text and open the context menu to see the built-in actions.

![Misty forest at sunrise](https://images.unsplash.com/photo-1448375240586-882707db888b?w=800)`;

const argTypes = {
  copyAsMarkdown: {
    control: 'boolean',
    description:
      'selectionMenuConfig.copyAsMarkdown — show "Copy as Markdown" in the selection menu.',
  },
  copyImageUrl: {
    control: 'boolean',
    description:
      'selectionMenuConfig.copyImageUrl — show "Copy Image URL" when the selection contains an image.',
  },
};

export default storyMeta('Props', 'Selection Menu');

export const Default: TextStory<SelectionMenuStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    copyAsMarkdown: true,
    copyImageUrl: true,
  },
  argTypes,
  render: ({ copyAsMarkdown, copyImageUrl, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Selection Menu"
      description='Built-in copy actions in the native selection menu. Select text for "Copy as Markdown"; select across the image for "Copy Image URL".'
      {...args}
      selectionMenuConfig={{ copyAsMarkdown, copyImageUrl }}
    />
  ),
};
