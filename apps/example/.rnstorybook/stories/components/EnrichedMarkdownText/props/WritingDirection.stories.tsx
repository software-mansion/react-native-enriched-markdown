import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type WritingDirection = 'auto' | 'ltr' | 'rtl' | 'first-strong';

type WritingDirectionStoryExtra = {
  writingDirection: WritingDirection;
};

const MARKDOWN = `# عنوان عربي

هذه فقرة عربية تتبع اتجاه اليمين إلى اليسار تلقائيًا حسب أول حرف قوي فيها.

This English paragraph stays left-to-right in the same document.

- عنصر عربي في القائمة
- English list item

> اقتباس عربي لاختبار موضع الحد الجانبي للاقتباس.

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
      "'first-strong' (default): resolve per paragraph from its first strong directional character; neutral-only paragraphs fall back to the view's layout direction. 'auto': React Native parity, follows the app's UI layout direction. 'ltr'/'rtl': force base direction on every paragraph. Code blocks always stay LTR.",
  },
};

export default storyMeta('Props', 'Writing Direction');

export const Default: TextStory<WritingDirectionStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    writingDirection: 'first-strong',
    flavor: 'github',
  },
  argTypes,
  render: ({ writingDirection, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Writing Direction"
      description="iOS only. Compare 'first-strong' (per-paragraph autodetection, matches Android) against 'auto' (RN parity — follows the app's UI direction), and the forced 'ltr'/'rtl' modes. Mixed Arabic/English content makes the difference visible at a glance."
      {...args}
      writingDirection={writingDirection}
    />
  ),
};
