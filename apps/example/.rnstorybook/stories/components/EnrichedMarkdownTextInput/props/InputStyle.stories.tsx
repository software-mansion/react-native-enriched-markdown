import React from 'react';
import type { TextStyle } from 'react-native';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';
import { numberControl } from '../../EnrichedMarkdownText/shared/storybookMarkdownStyles';

type InputStyleStoryExtra = {
  fontSize: number;
  color: string;
  paddingHorizontal: number;
  paddingVertical: number;
  minHeight: number;
  backgroundColor: string;
};

const MARKDOWN =
  '**Bold**, *italic*, and [a link](https://example.com) inside the styled input.';

const argTypes = {
  fontSize: numberControl('style.fontSize', { min: 12, max: 28, step: 1 }),
  color: {
    control: 'color',
    description: 'style.color — base text color for unformatted content.',
  },
  paddingHorizontal: numberControl('style.paddingHorizontal', {
    min: 0,
    max: 32,
    step: 2,
  }),
  paddingVertical: numberControl('style.paddingVertical', {
    min: 0,
    max: 32,
    step: 2,
  }),
  minHeight: numberControl('style.minHeight', { min: 80, max: 280, step: 10 }),
  backgroundColor: {
    control: 'color',
    description: 'style.backgroundColor',
  },
};

export default storyMeta('Props', 'Input Style');

export const Default: InputStory<InputStyleStoryExtra> = {
  args: {
    initialMarkdown: MARKDOWN,
    fontSize: 15,
    color: '#111827',
    paddingHorizontal: 14,
    paddingVertical: 12,
    minHeight: 120,
    backgroundColor: '#F9FAFB',
  },
  argTypes,
  render: ({
    fontSize,
    color,
    paddingHorizontal,
    paddingVertical,
    minHeight,
    backgroundColor,
    ...args
  }) => (
    <EnrichedMarkdownTextInputStory
      title="Input Style"
      description="style accepts ViewStyle and TextStyle props (fontSize, color, padding, minHeight, backgroundColor, etc.). Formatted spans use markdownStyle."
      {...args}
      style={buildInputStyle({
        fontSize,
        color,
        paddingHorizontal,
        paddingVertical,
        minHeight,
        backgroundColor,
      })}
    />
  ),
};

function buildInputStyle({
  fontSize,
  color,
  paddingHorizontal,
  paddingVertical,
  minHeight,
  backgroundColor,
}: InputStyleStoryExtra): TextStyle {
  return {
    fontSize,
    color,
    paddingHorizontal,
    paddingVertical,
    minHeight,
    backgroundColor,
  };
}
