import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import {
  EnrichedMarkdownTextStory,
  MarkdownStoryLayout,
} from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  githubFlavorArgTypes,
  inlineMathStyledDefaults,
  numberControl,
  type InlineMathStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toInlineMathStyle,
} from '../shared/storybookStyleBuilders';
import type { StoryArgs, TextStory } from '../shared/storyTypes';

const MARKDOWN = 'The formula $E = mc^2$ and $a^2 + b^2 = c^2$ are famous.';

const argTypes = {
  latexMath: {
    control: 'boolean',
    description: 'md4cFlags.latexMath — enable inline $...$ math parsing.',
  },
  color: {
    control: 'color',
    description: 'markdownStyle.inlineMath.color',
  },
  ...githubFlavorArgTypes('Inline math requires flavor="github" (GFM).'),
};

export default storyMeta('Inline', 'Inline Math');

export const Default: TextStory<InlineMathStyleControls> = {
  args: {
    markdown: MARKDOWN,
    flavor: 'github',
    ...inlineMathStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      inlineMathStyledDefaults
    );
    const { latexMath, ...inlineMathStyle } = controls;
    return (
      <EnrichedMarkdownTextStory
        title="Inline Math"
        description="Inline $...$ math. Block math is under Block/Math."
        {...rest}
        md4cFlags={{ latexMath }}
        style={{ inlineMath: toInlineMathStyle(inlineMathStyle) }}
      />
    );
  },
};

const FRACTION_CASES = [
  { label: 'Simple fraction', markdown: 'Foo $\\frac{4}{1}$' },
  {
    label: 'Displaystyle fraction with operators',
    markdown: '$\\left| \\displaystyle\\frac{(-6) \\cdot 5}{-2} \\right|$',
  },
  {
    label: 'Nested fractions',
    markdown: '$\\frac{\\frac{a}{b}}{\\frac{c}{d}}$',
  },
  {
    label: 'Mixed text and fraction',
    markdown:
      'The result is $\\frac{x^2 + 1}{2x - 3}$ which simplifies nicely.',
  },
];

type FractionControls = { fontSize: number; lineHeight: number; color: string };

const fractionDefaults: FractionControls = {
  fontSize: 18,
  lineHeight: 28,
  color: '#1e3a5f',
};

const fractionArgTypes = {
  fontSize: numberControl('markdownStyle.paragraph.fontSize', {
    min: 12,
    max: 48,
    step: 1,
  }),
  lineHeight: numberControl(
    'markdownStyle.paragraph.lineHeight — set to 0 to omit',
    { min: 0, max: 100, step: 1 }
  ),
  color: {
    control: 'color',
    description: 'markdownStyle.inlineMath.color',
  },
};

function FractionsStory(args: StoryArgs<FractionControls>) {
  const { fontSize, lineHeight, color, ...rest } = args;
  const [markdown, setMarkdown] = useState(
    FRACTION_CASES.map((c) => `${c.label}:\n${c.markdown}`).join('\n\n')
  );

  return (
    <MarkdownStoryLayout
      title="Inline Math — Fractions"
      description="Regression cases for fraction clipping when paragraph lineHeight is set."
      markdown={markdown}
      onMarkdownChange={setMarkdown}
      output={
        <View style={fractionStyles.cases}>
          {FRACTION_CASES.map((c) => (
            <View key={c.label} style={fractionStyles.caseRow}>
              <EnrichedMarkdownText
                {...rest}
                markdown={c.markdown}
                markdownStyle={{
                  paragraph: {
                    fontSize,
                    ...(lineHeight > 0 ? { lineHeight } : {}),
                  },
                  inlineMath: { color },
                }}
                containerStyle={fractionStyles.markdownContainer}
              />
            </View>
          ))}
        </View>
      }
    />
  );
}

export const Fractions: TextStory<FractionControls> = {
  args: {
    markdown: FRACTION_CASES.map((c) => c.markdown).join('\n\n'),
    flavor: 'github',
    ...fractionDefaults,
  },
  argTypes: fractionArgTypes,
  render: (args) => <FractionsStory {...args} />,
};

const fractionStyles = StyleSheet.create({
  cases: { gap: 16 },
  caseRow: {
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#e5e7eb',
    paddingBottom: 12,
  },
  markdownContainer: { backgroundColor: '#ffffff' },
});
