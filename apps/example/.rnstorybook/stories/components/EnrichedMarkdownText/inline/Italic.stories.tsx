import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  emphasisStyledDefaults,
  fontFamilyControl,
  type EmphasisStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toEmphasisStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = '*Italic text* and normal text.';

const argTypes = {
  fontFamily: fontFamilyControl('markdownStyle.em.fontFamily'),
  fontStyle: {
    options: ['italic', 'normal'],
    control: { type: 'inline-radio' },
    description:
      'markdownStyle.em.fontStyle — only applies when fontFamily is set.',
  },
  color: {
    control: 'color',
    description: 'markdownStyle.em.color',
  },
};

export default storyMeta('Inline', 'Italic');

export const Default: TextStory<EmphasisStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...emphasisStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, emphasisStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Italic"
        description="*text* renders as emphasis. (_text_ is covered under Inline/Underline when md4cFlags.underline is on.)"
        {...rest}
        md4cFlags={{ underline: false }}
        style={{ em: toEmphasisStyle(controls) }}
      />
    );
  },
};
