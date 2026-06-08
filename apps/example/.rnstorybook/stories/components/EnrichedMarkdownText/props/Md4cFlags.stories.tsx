import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import {
  githubFlavorArgTypes,
  type MarkdownFlavor,
} from '../shared/storybookMarkdownStyles';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type Md4cFlagsStoryExtra = {
  underline: boolean;
  superscript: boolean;
  subscript: boolean;
  latexMath: boolean;
  flavor: MarkdownFlavor;
};

const MARKDOWN = `_underline_

text^superscript^

text~subscript~

$E = mc^2$`;

const argTypes = {
  underline: {
    control: 'boolean',
    description:
      'md4cFlags.underline — _text_ becomes underline instead of emphasis.',
  },
  superscript: {
    control: 'boolean',
    description: 'md4cFlags.superscript — ^text^ parsing.',
  },
  subscript: {
    control: 'boolean',
    description:
      'md4cFlags.subscript — ~text~ parsing (disables single-tilde strikethrough).',
  },
  latexMath: {
    control: 'boolean',
    description: 'md4cFlags.latexMath — $...$ and $$...$$ math parsing.',
  },
  ...githubFlavorArgTypes('LaTeX math requires flavor="github".'),
};

// Sidebar title uses "Md4c-Flags"; file name follows camelCase convention.
export default storyMeta('Props', 'Md4c-Flags');

export const Default: TextStory<Md4cFlagsStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    underline: true,
    superscript: true,
    subscript: true,
    latexMath: true,
    flavor: 'github',
  },
  argTypes,
  render: ({ underline, superscript, subscript, latexMath, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Md4c-Flags"
      description="Cross-cutting md4cFlags demo. Individual inline/block stories also expose the minimum flag each syntax needs."
      {...args}
      md4cFlags={{ underline, superscript, subscript, latexMath }}
    />
  ),
};
