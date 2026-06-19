import React from 'react';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import {
  inputStrongDefaults,
  type InputStrongStyleControls,
} from '../shared/storybookInputStyles';
import {
  splitStyleControls,
  toInputStrongStyle,
} from '../shared/storybookInputStyleBuilders';
import type { InputStory } from '../shared/storyTypes';

const argTypes = {
  color: {
    control: 'color',
    description: 'markdownStyle.strong.color',
  },
};

export default storyMeta('Inline', 'Bold');

export const Default: InputStory<InputStrongStyleControls> = {
  args: {
    initialMarkdown: '**Bold text** and normal text.',
    ...inputStrongDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, inputStrongDefaults);
    return (
      <EnrichedMarkdownTextInputStory
        title="Bold"
        description="**text** renders as strong. Select text or position the cursor and tap Bold in the toolbar."
        {...rest}
        markdownStyle={{ strong: toInputStrongStyle(controls) }}
      />
    );
  },
};
