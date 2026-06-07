import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  strikethroughStyledDefaults,
  type StrikethroughStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toStrikethroughStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = '~~Strikethrough text~~ and normal text.';

const argTypes = {
  color: {
    name: 'color (iOS only)',
    control: 'color',
    description: 'markdownStyle.strikethrough.color',
  },
};

export default storyMeta('Inline', 'Strikethrough');

export const Default: TextStory<StrikethroughStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...strikethroughStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      strikethroughStyledDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Strikethrough"
        description="~~text~~ renders with a strike line. ~~ still works when md4cFlags.subscript is on; only single ~ is affected. Strikethrough color is iOS-only."
        {...rest}
        style={{ strikethrough: toStrikethroughStyle(controls) }}
      />
    );
  },
};
