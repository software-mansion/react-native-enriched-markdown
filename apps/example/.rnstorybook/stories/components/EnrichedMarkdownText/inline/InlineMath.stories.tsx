import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  githubFlavorArgTypes,
  inlineMathStyledDefaults,
  type InlineMathStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toInlineMathStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = 'The formula $E = mc^2$ and $a^2 + b^2 = c^2$ are famous.';

const argTypes = {
  latexMath: {
    control: 'boolean',
    description: 'md4cFlags.latexMath — enable inline $...$ math parsing.',
  },
  color: {
    control: 'color',
    description: 'markdownStyle.inlineMath.color',
  },
  ...githubFlavorArgTypes('Inline math requires flavor="github" (GFM).'),
};

export default storyMeta('Inline', 'Inline Math');

export const Default: TextStory<InlineMathStyleControls> = {
  args: {
    markdown: MARKDOWN,
    flavor: 'github',
    ...inlineMathStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      inlineMathStyledDefaults
    );
    const { latexMath, ...inlineMathStyle } = controls;
    return (
      <EnrichedMarkdownTextStory
        title="Inline Math"
        description="Inline $...$ math. Block math is under Block/Math."
        {...rest}
        md4cFlags={{ latexMath }}
        style={{ inlineMath: toInlineMathStyle(inlineMathStyle) }}
      />
    );
  },
};
