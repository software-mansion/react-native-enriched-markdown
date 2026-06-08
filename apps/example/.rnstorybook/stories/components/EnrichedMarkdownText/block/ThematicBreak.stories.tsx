import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  thematicBreakStyledDefaults,
  type ThematicBreakStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toThematicBreakStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = `---

***

___`;

const argTypes = {
  color: {
    control: 'color',
    description: 'markdownStyle.thematicBreak.color',
  },
  height: numberControl('markdownStyle.thematicBreak.height', {
    min: 1,
    max: 8,
    step: 1,
  }),
  marginTop: numberControl('markdownStyle.thematicBreak.marginTop', {
    min: 0,
    max: 48,
    step: 4,
  }),
  marginBottom: numberControl('markdownStyle.thematicBreak.marginBottom', {
    min: 0,
    max: 48,
    step: 4,
  }),
};

export default storyMeta('Block', 'Thematic Break');

export const Default: TextStory<ThematicBreakStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...thematicBreakStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      thematicBreakStyledDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Thematic Break"
        description="Horizontal rules via ---, ***, or ___. Use the controls to tune markdownStyle.thematicBreak."
        {...rest}
        style={{ thematicBreak: toThematicBreakStyle(controls) }}
      />
    );
  },
};
