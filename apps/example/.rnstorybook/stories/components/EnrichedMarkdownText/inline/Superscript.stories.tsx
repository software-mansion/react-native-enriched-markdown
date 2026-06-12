import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  scriptStyleArgTypes,
  superscriptStyledDefaults,
  type SuperscriptStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toSuperscriptStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = 'Water is H^2^O and area scales as x^2^.';

const argTypes = {
  superscript: {
    control: 'boolean',
    description: 'md4cFlags.superscript — enable ^text^ parsing.',
  },
  ...scriptStyleArgTypes('superscript'),
};

export default storyMeta('Inline', 'Superscript');

export const Default: TextStory<SuperscriptStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...superscriptStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      superscriptStyledDefaults
    );
    const { superscript, ...superscriptStyle } = controls;
    return (
      <EnrichedMarkdownTextStory
        title="Superscript"
        description="^text^ requires md4cFlags.superscript. Tune markdownStyle.superscript."
        {...rest}
        md4cFlags={{ superscript }}
        style={{ superscript: toSuperscriptStyle(superscriptStyle) }}
      />
    );
  },
};
