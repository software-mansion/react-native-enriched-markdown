import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type SelectionStoryExtra = {
  selectable: boolean;
  selectionColor: string;
  selectionHandleColor: string;
};

const argTypes = {
  selectable: {
    control: 'boolean',
    description: 'Allow text to be selected.',
  },
  selectionColor: {
    control: 'color',
    description:
      'Selection highlight. On iOS also tints the caret and drag handles.',
  },
  selectionHandleColor: {
    name: 'selectionHandleColor (Android only)',
    control: 'color',
    description:
      'Drag handle color. Android API 29+ only — no effect on iOS (use selectionColor there).',
  },
};

export default storyMeta('Props', 'Selection');

export const Default: TextStory<SelectionStoryExtra> = {
  args: {
    markdown: 'Select some of this text to see the highlight color in action.',
    selectable: true,
    selectionColor: '#b4d5fe',
    selectionHandleColor: '#2563eb',
  },
  argTypes,
  render: ({ selectionColor, selectionHandleColor, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Selection"
      description="Change a color, then select text again to see it applied (iOS does not repaint an active selection). selectionHandleColor is Android-only (API 29+) — on iOS, use selectionColor for handles too."
      {...args}
      selectionColor={selectionColor}
      selectionHandleColor={selectionHandleColor}
    />
  ),
};
