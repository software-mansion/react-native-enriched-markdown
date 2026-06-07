import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  scriptStyleArgTypes,
  subscriptStyledDefaults,
  type SubscriptStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toSubscriptStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = 'Water is H~2~O and the index is x~1~.';

const argTypes = {
  subscript: {
    control: 'boolean',
    description:
      'md4cFlags.subscript — enable ~text~ parsing (disables single-tilde strikethrough).',
  },
  ...scriptStyleArgTypes('subscript'),
};

export default storyMeta('Inline', 'Subscript');

export const Default: TextStory<SubscriptStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...subscriptStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      subscriptStyledDefaults
    );
    const { subscript, ...subscriptStyle } = controls;
    return (
      <EnrichedMarkdownTextStory
        title="Subscript"
        description="~text~ requires md4cFlags.subscript. Tune markdownStyle.subscript."
        {...rest}
        md4cFlags={{ subscript }}
        style={{ subscript: toSubscriptStyle(subscriptStyle) }}
      />
    );
  },
};
