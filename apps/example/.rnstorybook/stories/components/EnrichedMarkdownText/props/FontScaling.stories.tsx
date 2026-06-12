import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { numberControl } from '../shared/storybookMarkdownStyles';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type FontScalingStoryExtra = {
  allowFontScaling: boolean;
  maxFontSizeMultiplier: number;
};

const MARKDOWN =
  'This text respects system font scaling when allowFontScaling is enabled.';

const argTypes = {
  allowFontScaling: {
    control: 'boolean',
    description:
      'When false, text ignores the user accessibility font size setting.',
  },
  maxFontSizeMultiplier: numberControl(
    'maxFontSizeMultiplier — caps scaling when allowFontScaling is on. 0 means no limit.',
    { min: 0, max: 3, step: 0.25 }
  ),
};

export default storyMeta('Props', 'Font Scaling');

export const Default: TextStory<FontScalingStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    allowFontScaling: true,
    maxFontSizeMultiplier: 0,
  },
  argTypes,
  render: ({ allowFontScaling, maxFontSizeMultiplier, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Font Scaling"
      description="Accessibility font scaling props (iOS, Android). Change system text size to verify."
      {...args}
      allowFontScaling={allowFontScaling}
      maxFontSizeMultiplier={
        maxFontSizeMultiplier > 0 ? maxFontSizeMultiplier : undefined
      }
    />
  ),
};
