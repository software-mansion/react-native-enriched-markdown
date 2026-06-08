import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  inlineCodeStyledDefaults,
  type InlineCodeStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toInlineCodeStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = 'Use `pthread*` to debug and `null` to clear.';

const argTypes = {
  fontFamily: fontFamilyControl('markdownStyle.code.fontFamily'),
  fontSize: numberControl(
    'markdownStyle.code.fontSize — 0 inherits parent size.',
    { min: 0, max: 24, step: 1 }
  ),
  color: {
    control: 'color',
    description: 'markdownStyle.code.color',
  },
  backgroundColor: {
    control: 'color',
    description: 'markdownStyle.code.backgroundColor',
  },
  borderColor: {
    control: 'color',
    description: 'markdownStyle.code.borderColor',
  },
};

export default storyMeta('Inline', 'Inline Code');

export const Default: TextStory<InlineCodeStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...inlineCodeStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      inlineCodeStyledDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Inline Code"
        description="`code` spans use markdownStyle.code."
        {...rest}
        style={{ code: toInlineCodeStyle(controls) }}
      />
    );
  },
};
