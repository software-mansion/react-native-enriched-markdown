import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  githubFlavorArgTypes,
  type MarkdownFlavor,
} from '../shared/storybookMarkdownStyles';
import type { TextStory } from '../shared/storyTypes';

type FlavorStoryExtra = {
  flavor: MarkdownFlavor;
};

const MARKDOWN = `CommonMark paragraph.

| col | val |
| --- | --- |
| a   | 1   |

- [x] GFM task list item`;

const argTypes = githubFlavorArgTypes(
  'commonmark — single TextView renderer. github — GFM tables, task lists, math, etc.'
);

export default storyMeta('Props', 'Flavor');

export const Default: TextStory<FlavorStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    flavor: 'github',
  },
  argTypes,
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Flavor"
      description='Cross-cutting flavor demo. GFM-only syntax (tables, task lists, math) needs flavor="github". Block/Table, Block/Task List, Block/Math, and Inline/Math also expose flavor where required.'
      {...args}
    />
  ),
};
