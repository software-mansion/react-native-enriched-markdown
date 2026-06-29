import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type AccessibilityLabelsStoryExtra = {
  bulletPoint: string;
  nestedBulletPoint: string;
  orderedItem: string;
  nestedOrderedItem: string;
  tableRow: string;
  mathEquation: string;
  rotorHeadings: string;
  rotorLinks: string;
  rotorImages: string;
};

const MARKDOWN = `# Heading level 1

A paragraph with an inline [link](https://example.com).

- Top-level bullet
- Another bullet
  - Nested bullet
  - Another nested bullet

1. Top-level ordered item
2. Another ordered item
   1. Nested ordered item
   2. Another nested ordered item

| Column A | Column B |
|----------|----------|
| Cell A1  | Cell B1  |
| Cell A2  | Cell B2  |

$$E = mc^2$$

![Sample image](https://placehold.co/200x80/png?text=Image)`;

const argTypes = {
  bulletPoint: {
    control: 'text',
    description:
      'accessibilityLabels.list.bulletPoint — top-level unordered item announcement.',
  },
  nestedBulletPoint: {
    control: 'text',
    description:
      'accessibilityLabels.list.nestedBulletPoint — nested unordered item announcement.',
  },
  orderedItem: {
    control: 'text',
    description:
      'accessibilityLabels.list.orderedItem — ordered item announcement. `{n}` → 1-based index.',
  },
  nestedOrderedItem: {
    control: 'text',
    description:
      'accessibilityLabels.list.nestedOrderedItem — nested ordered item. `{n}` → 1-based index.',
  },
  tableRow: {
    control: 'text',
    description:
      'accessibilityLabels.table.row — table row. `{n}` → 1-based row index, `{content}` → joined cell texts.',
  },
  mathEquation: {
    control: 'text',
    description:
      'accessibilityLabels.math.equation — math equation. `{latex}` → equation source.',
  },
  rotorHeadings: {
    control: 'text',
    description:
      'accessibilityLabels.rotor.headings — VoiceOver headings rotor name (iOS only).',
  },
  rotorLinks: {
    control: 'text',
    description:
      'accessibilityLabels.rotor.links — VoiceOver links rotor name (iOS only).',
  },
  rotorImages: {
    control: 'text',
    description:
      'accessibilityLabels.rotor.images — VoiceOver images rotor name (iOS only).',
  },
};

export default storyMeta('Props', 'Accessibility Labels');

export const Default: TextStory<AccessibilityLabelsStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    bulletPoint: 'Bullet point',
    nestedBulletPoint: 'Nested bullet point',
    orderedItem: 'List item {n}',
    nestedOrderedItem: 'Nested list item {n}',
    tableRow: 'Row {n}: {content}',
    mathEquation: 'Math: {latex}',
    rotorHeadings: 'Headings',
    rotorLinks: 'Links',
    rotorImages: 'Images',
  },
  argTypes,
  render: ({
    bulletPoint,
    nestedBulletPoint,
    orderedItem,
    nestedOrderedItem,
    tableRow,
    mathEquation,
    rotorHeadings,
    rotorLinks,
    rotorImages,
    ...args
  }) => (
    <EnrichedMarkdownTextStory
      title="Accessibility Labels"
      description="Strings spoken by VoiceOver (iOS) and TalkBack (Android). Edit any field and toggle the screen reader to hear the override. Placeholders ({n}, {content}, {latex}) are substituted at speak time. Rotor labels are iOS-only."
      {...args}
      accessibilityLabels={{
        list: {
          bulletPoint,
          nestedBulletPoint,
          orderedItem,
          nestedOrderedItem,
        },
        table: { row: tableRow },
        math: { equation: mathEquation },
        rotor: {
          headings: rotorHeadings,
          links: rotorLinks,
          images: rotorImages,
        },
      }}
    />
  ),
};
