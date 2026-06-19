import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  fontWeightControl,
  paragraphStyledDefaults,
  type ParagraphStyleControls,
  numberControl,
  textAlignControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toParagraphStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = `Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.

It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages.`;

const argTypes = {
  fontSize: numberControl('markdownStyle.paragraph.fontSize', {
    min: 12,
    max: 32,
    step: 1,
  }),
  fontFamily: fontFamilyControl('markdownStyle.paragraph.fontFamily'),
  fontWeight: fontWeightControl('markdownStyle.paragraph.fontWeight'),
  color: {
    control: 'color',
    description: 'markdownStyle.paragraph.color',
  },
  marginTop: numberControl('markdownStyle.paragraph.marginTop', {
    min: 0,
    max: 48,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.paragraph.marginBottom', {
    min: 0,
    max: 48,
    step: 2,
  }),
  lineHeight: numberControl('markdownStyle.paragraph.lineHeight', {
    min: 16,
    max: 48,
    step: 1,
  }),
  textAlign: textAlignControl('markdownStyle.paragraph.textAlign'),
};

export default storyMeta('Block', 'Paragraph');

export const Default: TextStory<ParagraphStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...paragraphStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      paragraphStyledDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Paragraph"
        description="Plain body text. Use the controls to tune markdownStyle.paragraph."
        {...rest}
        style={{ paragraph: toParagraphStyle(controls) }}
      />
    );
  },
};
