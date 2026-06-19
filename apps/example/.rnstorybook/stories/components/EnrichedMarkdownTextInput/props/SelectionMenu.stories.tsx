import React from 'react';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

type SelectionMenuStoryExtra = {
  format: boolean;
  copyAsMarkdown: boolean;
};

const MARKDOWN =
  'Select this text and open the context menu to see the built-in actions.';

const argTypes = {
  format: {
    control: 'boolean',
    description:
      'selectionMenuConfig.format — show the "Format" submenu (Bold, Italic, etc.) in the selection menu.',
  },
  copyAsMarkdown: {
    control: 'boolean',
    description:
      'selectionMenuConfig.copyAsMarkdown — show "Copy as Markdown" in the selection menu.',
  },
};

export default storyMeta('Props', 'Selection Menu');

export const Default: InputStory<SelectionMenuStoryExtra> = {
  args: {
    initialMarkdown: MARKDOWN,
    format: true,
    copyAsMarkdown: true,
  },
  argTypes,
  render: ({ format, copyAsMarkdown, ...args }) => (
    <EnrichedMarkdownTextInputStory
      title="Selection Menu"
      description="selectionMenuConfig controls built-in items in the native selection menu. Toggle the controls to show/hide the Format submenu and Copy as Markdown action."
      {...args}
      selectionMenuConfig={{ format, copyAsMarkdown }}
    />
  ),
};
