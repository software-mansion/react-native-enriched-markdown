import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  highlightStyledDefaults,
  type HighlightStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toHighlightStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN =
  'This is ==highlighted text== in a sentence. Combine with ==**bold**== or ==*italic*==.';

const argTypes = {
  highlight: {
    control: 'boolean',
    description: 'md4cFlags.highlight — enable ==text== parsing.',
  },
  color: {
    control: 'color',
    description:
      'markdownStyle.highlight.color — inherits block color when omitted.',
  },
  backgroundColor: {
    control: 'color',
    description: 'markdownStyle.highlight.backgroundColor',
  },
};

export default storyMeta('Inline', 'Highlight');

export const Default: TextStory<HighlightStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...highlightStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      highlightStyledDefaults
    );
    const { highlight, ...highlightStyle } = controls;
    return (
      <EnrichedMarkdownTextStory
        title="Highlight"
        description="==text== requires md4cFlags.highlight. Font inherits from the block; only color and backgroundColor are overridden."
        {...rest}
        md4cFlags={{ highlight }}
        style={{ highlight: toHighlightStyle(highlightStyle) }}
      />
    );
  },
};
