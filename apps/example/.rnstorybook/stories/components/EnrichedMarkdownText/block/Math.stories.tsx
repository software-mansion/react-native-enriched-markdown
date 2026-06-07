import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  githubFlavorArgTypes,
  mathStyledDefaults,
  type MathStyleControls,
  mathTextAlignControl,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toMathStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = `$$
E = mc^2
$$

$$
\\int_{a}^{b} f(x)\\,dx = F(b) - F(a)
$$

$$
\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
$$`;

const argTypes = {
  ...githubFlavorArgTypes('Block math requires flavor="github" (GFM).'),
  latexMath: {
    control: 'boolean',
    description: 'md4cFlags.latexMath — enable block and inline math parsing.',
  },
  fontSize: numberControl('markdownStyle.math.fontSize', {
    min: 12,
    max: 24,
    step: 1,
  }),
  color: {
    control: 'color',
    description: 'markdownStyle.math.color',
  },
  backgroundColor: {
    control: 'color',
    description: 'markdownStyle.math.backgroundColor',
  },
  padding: numberControl('markdownStyle.math.padding', {
    min: 0,
    max: 24,
    step: 2,
  }),
  marginTop: numberControl('markdownStyle.math.marginTop', {
    min: 0,
    max: 48,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.math.marginBottom', {
    min: 0,
    max: 48,
    step: 2,
  }),
  textAlign: mathTextAlignControl('markdownStyle.math.textAlign'),
};

export default storyMeta('Block', 'Math');

export const Default: TextStory<MathStyleControls> = {
  args: {
    markdown: MARKDOWN,
    flavor: 'github',
    ...mathStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, mathStyledDefaults);
    const { latexMath, ...mathStyle } = controls;
    return (
      <EnrichedMarkdownTextStory
        title="Math"
        description='Block math via $$...$$. Requires flavor="github" and md4cFlags.latexMath. Use the controls to tune markdownStyle.math.'
        {...rest}
        md4cFlags={{ latexMath }}
        style={{ math: toMathStyle(mathStyle) }}
      />
    );
  },
};
