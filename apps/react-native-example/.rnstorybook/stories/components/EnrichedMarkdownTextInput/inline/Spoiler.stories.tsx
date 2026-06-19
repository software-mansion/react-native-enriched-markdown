import React from 'react';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import {
  inputSpoilerDefaults,
  type InputSpoilerStyleControls,
} from '../shared/storybookInputStyles';
import {
  splitStyleControls,
  toInputSpoilerStyle,
} from '../shared/storybookInputStyleBuilders';
import type { InputStory } from '../shared/storyTypes';

const argTypes = {
  color: {
    control: 'color',
    description: 'markdownStyle.spoiler.color',
  },
  backgroundColor: {
    control: 'color',
    description: 'markdownStyle.spoiler.backgroundColor',
  },
};

export default storyMeta('Inline', 'Spoiler');

export const Default: InputStory<InputSpoilerStyleControls> = {
  args: {
    initialMarkdown: 'The answer is ||spoiler text||.',
    ...inputSpoilerDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, inputSpoilerDefaults);
    return (
      <EnrichedMarkdownTextInputStory
        title="Spoiler"
        description="||text|| renders as spoiler. Select text or position the cursor and tap Spoiler in the toolbar."
        {...rest}
        markdownStyle={{ spoiler: toInputSpoilerStyle(controls) }}
      />
    );
  },
};
