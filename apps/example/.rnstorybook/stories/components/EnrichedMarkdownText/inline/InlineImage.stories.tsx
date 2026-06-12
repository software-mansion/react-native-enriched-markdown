import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  inlineImageStyledDefaults,
  type InlineImageStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toInlineImageStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN =
  'Text with an inline image ![tiny](https://placehold.co/100x100/png?text=I) in the flow.';

const argTypes = {
  size: numberControl('markdownStyle.inlineImage.size', {
    min: 12,
    max: 64,
    step: 2,
  }),
};

export default storyMeta('Inline', 'Inline Image');

export const Default: TextStory<InlineImageStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...inlineImageStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      inlineImageStyledDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Inline Image"
        description="![alt](url) inside a paragraph uses markdownStyle.inlineImage."
        {...rest}
        style={{ inlineImage: toInlineImageStyle(controls) }}
      />
    );
  },
};
