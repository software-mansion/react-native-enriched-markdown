import React from 'react';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

type WritingDirection = 'auto' | 'ltr' | 'rtl' | 'first-strong';

type WritingDirectionStoryExtra = {
  writingDirection: WritingDirection;
};

const INITIAL_MARKDOWN = `# عنوان عربي

هذه فقرة عربية تتبع اتجاه اليمين إلى اليسار تلقائيًا حسب أول حرف قوي فيها.

This English paragraph stays left-to-right in the same document.

123 456 789.`;

const WRITING_DIRECTION_OPTIONS: WritingDirection[] = [
  'first-strong',
  'auto',
  'ltr',
  'rtl',
];

const argTypes = {
  writingDirection: {
    options: WRITING_DIRECTION_OPTIONS,
    control: { type: 'inline-radio' as const },
    description:
      "'first-strong' (default): resolve per paragraph from its first strong directional character; neutral-only paragraphs fall back to the view's layout direction. 'auto': React Native parity, follows the app's UI layout direction. 'ltr'/'rtl': force base direction on every paragraph.",
  },
};

export default storyMeta('Props', 'Writing Direction');

export const Default: InputStory<WritingDirectionStoryExtra> = {
  args: {
    initialMarkdown: INITIAL_MARKDOWN,
    writingDirection: 'first-strong',
  },
  argTypes,
  render: ({ writingDirection, ...args }) => (
    <EnrichedMarkdownTextInputStory
      title="Writing Direction"
      description="iOS only. Type Arabic/Hebrew/Persian to see per-paragraph auto-detection; switch modes to compare against 'auto' (RN parity — follows the app's UI direction), and forced 'ltr'/'rtl'. Android always uses first-strong via the platform EditText."
      {...args}
      writingDirection={writingDirection}
    />
  ),
};
