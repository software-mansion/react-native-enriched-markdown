import React from 'react';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

type FormatMenuStoryExtra = {
  bold: boolean;
  italic: boolean;
  underline: boolean;
  strikethrough: boolean;
  spoiler: boolean;
  link: boolean;
};

const MARKDOWN =
  'Select this text and open the Format submenu to see which items are visible.';

const argTypes = {
  bold: {
    control: 'boolean',
    description: 'formatMenuConfig.bold — show "Bold" in the Format submenu.',
  },
  italic: {
    control: 'boolean',
    description:
      'formatMenuConfig.italic — show "Italic" in the Format submenu.',
  },
  underline: {
    control: 'boolean',
    description:
      'formatMenuConfig.underline — show "Underline" in the Format submenu.',
  },
  strikethrough: {
    control: 'boolean',
    description:
      'formatMenuConfig.strikethrough — show "Strikethrough" in the Format submenu.',
  },
  spoiler: {
    control: 'boolean',
    description:
      'formatMenuConfig.spoiler — show "Spoiler" in the Format submenu.',
  },
  link: {
    control: 'boolean',
    description: 'formatMenuConfig.link — show "Link" in the Format submenu.',
  },
};

export default storyMeta('Props', 'Format Menu');

export const Default: InputStory<FormatMenuStoryExtra> = {
  args: {
    initialMarkdown: MARKDOWN,
    bold: true,
    italic: true,
    underline: true,
    strikethrough: true,
    spoiler: true,
    link: true,
  },
  argTypes,
  render: ({
    bold,
    italic,
    underline,
    strikethrough,
    spoiler,
    link,
    ...args
  }) => (
    <EnrichedMarkdownTextInputStory
      title="Format Menu"
      description="formatMenuConfig controls which items appear in the Format submenu. Toggle the controls to show/hide individual formatting actions."
      {...args}
      formatMenuConfig={{
        bold,
        italic,
        underline,
        strikethrough,
        spoiler,
        link,
      }}
    />
  ),
};
