import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  underlineStyledDefaults,
  type UnderlineStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toUnderlineStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = '__Underlined text__ normal text _single underline_.';

const argTypes = {
  underline: {
    control: 'boolean',
    description:
      'md4cFlags.underline — when on, _text_ renders as underline instead of emphasis.',
  },
  color: {
    name: 'color (iOS only)',
    control: 'color',
    description: 'markdownStyle.underline.color',
  },
};

export default storyMeta('Inline', 'Underline');

export const Default: TextStory<UnderlineStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...underlineStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      underlineStyledDefaults
    );
    const { underline, ...underlineStyle } = controls;
    return (
      <EnrichedMarkdownTextStory
        title="Underline"
        description="Requires md4cFlags.underline. Tune markdownStyle.underline (iOS only)."
        {...rest}
        md4cFlags={{ underline }}
        style={{ underline: toUnderlineStyle(underlineStyle) }}
      />
    );
  },
};
