import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  imageStyledDefaults,
  type ImageStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toImageStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN =
  '![Misty forest at sunrise](https://images.unsplash.com/photo-1448375240586-882707db888b?w=800)';

const argTypes = {
  height: numberControl('markdownStyle.image.height', {
    min: 80,
    max: 400,
    step: 10,
  }),
  maxHeight: numberControl('markdownStyle.image.maxHeight (0 = off)', {
    min: 0,
    max: 400,
    step: 10,
  }),
  aspectRatio: numberControl('markdownStyle.image.aspectRatio (0 = off)', {
    min: 0,
    max: 3,
    step: 0.1,
  }),
  resizeMode: {
    options: ['', 'contain', 'cover', 'stretch', 'center', 'none'] as const,
    control: { type: 'select' as const },
    description: "markdownStyle.image.resizeMode ('' = legacy sizing)",
  },
  borderRadius: numberControl('markdownStyle.image.borderRadius', {
    min: 0,
    max: 24,
    step: 2,
  }),
  marginTop: numberControl('markdownStyle.image.marginTop', {
    min: 0,
    max: 32,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.image.marginBottom', {
    min: 0,
    max: 32,
    step: 2,
  }),
};

export default storyMeta('Block', 'Image');

export const Default: TextStory<ImageStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...imageStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, imageStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Image"
        description="Block images via ![alt](url). Use the controls to tune markdownStyle.image."
        {...rest}
        style={{ image: toImageStyle(controls) }}
      />
    );
  },
};
