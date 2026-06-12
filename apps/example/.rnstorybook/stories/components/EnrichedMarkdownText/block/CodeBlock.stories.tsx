import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  codeBlockStyledDefaults,
  fontFamilyControl,
  fontWeightControl,
  type CodeBlockStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toCodeBlockStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = `\`\`\`
sum = 0
for i in range(20):
  print(i % 3)
  sum += i % 3
  
print(sum)
\`\`\``;

const argTypes = {
  fontSize: numberControl('markdownStyle.codeBlock.fontSize', {
    min: 10,
    max: 20,
    step: 1,
  }),
  fontFamily: fontFamilyControl('markdownStyle.codeBlock.fontFamily'),
  fontWeight: fontWeightControl('markdownStyle.codeBlock.fontWeight'),
  color: {
    control: 'color',
    description: 'markdownStyle.codeBlock.color',
  },
  marginTop: numberControl('markdownStyle.codeBlock.marginTop', {
    min: 0,
    max: 48,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.codeBlock.marginBottom', {
    min: 0,
    max: 48,
    step: 2,
  }),
  lineHeight: numberControl('markdownStyle.codeBlock.lineHeight', {
    min: 14,
    max: 32,
    step: 1,
  }),
  backgroundColor: {
    control: 'color',
    description: 'markdownStyle.codeBlock.backgroundColor',
  },
  borderColor: {
    control: 'color',
    description: 'markdownStyle.codeBlock.borderColor',
  },
  borderRadius: numberControl('markdownStyle.codeBlock.borderRadius', {
    min: 0,
    max: 16,
    step: 1,
  }),
  borderWidth: numberControl('markdownStyle.codeBlock.borderWidth', {
    min: 0,
    max: 4,
    step: 1,
  }),
  padding: numberControl('markdownStyle.codeBlock.padding', {
    min: 0,
    max: 32,
    step: 2,
  }),
};

export default storyMeta('Block', 'Code Block');

export const Default: TextStory<CodeBlockStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...codeBlockStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      codeBlockStyledDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Code Block"
        description="Fenced code blocks with triple backticks. Use the controls to tune markdownStyle.codeBlock."
        {...rest}
        style={{ codeBlock: toCodeBlockStyle(controls) }}
      />
    );
  },
};
