import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  strongFontWeightControl,
  strongStyledDefaults,
  type StrongStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toStrongStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = '**Bold text** and normal text.';

const argTypes = {
  fontFamily: fontFamilyControl('markdownStyle.strong.fontFamily'),
  fontWeight: strongFontWeightControl(
    'markdownStyle.strong.fontWeight — only applies when fontFamily is set.'
  ),
  color: {
    control: 'color',
    description: 'markdownStyle.strong.color',
  },
};

export default storyMeta('Inline', 'Bold');

export const Default: TextStory<StrongStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...strongStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, strongStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Bold"
        description="**text** renders as strong. (__text__ is covered under Inline/Underline when md4cFlags.underline is on.)"
        {...rest}
        style={{ strong: toStrongStyle(controls) }}
      />
    );
  },
};
