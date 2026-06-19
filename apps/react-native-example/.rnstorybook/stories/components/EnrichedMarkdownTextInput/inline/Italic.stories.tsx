import React from 'react';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import {
  inputEmDefaults,
  type InputEmStyleControls,
} from '../shared/storybookInputStyles';
import {
  splitStyleControls,
  toInputEmStyle,
} from '../shared/storybookInputStyleBuilders';
import type { InputStory } from '../shared/storyTypes';

const argTypes = {
  color: {
    control: 'color',
    description: 'markdownStyle.em.color',
  },
};

export default storyMeta('Inline', 'Italic');

export const Default: InputStory<InputEmStyleControls> = {
  args: {
    initialMarkdown: '*Italic text* and normal text.',
    ...inputEmDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, inputEmDefaults);
    return (
      <EnrichedMarkdownTextInputStory
        title="Italic"
        description="*text* renders as emphasis. Select text or position the cursor and tap Italic in the toolbar."
        {...rest}
        markdownStyle={{ em: toInputEmStyle(controls) }}
      />
    );
  },
};
