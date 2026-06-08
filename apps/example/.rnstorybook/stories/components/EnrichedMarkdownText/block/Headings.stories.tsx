import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  fontWeightControl,
  headingStyledDefaultsByLevel,
  type HeadingLevel,
  type SingleHeadingStyleControls,
  numberControl,
  textAlignControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toHeadingStyleAtLevel,
} from '../shared/storybookStyleBuilders';
import type { StoryArgs, TextStory } from '../shared/storyTypes';

const HEADING_MARKDOWN: Record<HeadingLevel, string> = {
  1: '# Heading 1',
  2: '## Heading 2',
  3: '### Heading 3',
  4: '#### Heading 4',
  5: '##### Heading 5',
  6: '###### Heading 6',
};

const FONT_SIZE_RANGES: Record<HeadingLevel, { min: number; max: number }> = {
  1: { min: 20, max: 40 },
  2: { min: 18, max: 36 },
  3: { min: 16, max: 32 },
  4: { min: 14, max: 28 },
  5: { min: 12, max: 24 },
  6: { min: 10, max: 20 },
};

function createHeadingArgTypes(level: HeadingLevel) {
  const styleKey = `h${level}`;
  const { min, max } = FONT_SIZE_RANGES[level];

  return {
    fontSize: numberControl(`markdownStyle.${styleKey}.fontSize`, {
      min,
      max,
      step: 1,
    }),
    fontFamily: fontFamilyControl(`markdownStyle.${styleKey}.fontFamily`),
    fontWeight: fontWeightControl(`markdownStyle.${styleKey}.fontWeight`),
    color: {
      control: 'color',
      description: `markdownStyle.${styleKey}.color`,
    },
    lineHeight: numberControl(`markdownStyle.${styleKey}.lineHeight`, {
      min: 16,
      max: 48,
      step: 1,
    }),
    textAlign: textAlignControl(`markdownStyle.${styleKey}.textAlign`),
    marginTop: numberControl(`markdownStyle.${styleKey}.marginTop`, {
      min: 0,
      max: 48,
      step: 2,
    }),
    marginBottom: numberControl(`markdownStyle.${styleKey}.marginBottom`, {
      min: 0,
      max: 24,
      step: 2,
    }),
  };
}

function renderHeading(
  level: HeadingLevel,
  args: StoryArgs<SingleHeadingStyleControls>
) {
  const defaults = headingStyledDefaultsByLevel[level];
  const { controls, rest } = splitStyleControls(args, defaults);

  return (
    <EnrichedMarkdownTextStory
      title={`Heading ${level}`}
      description={`Single H${level} sample. Use the controls to tune markdownStyle.h${level}.`}
      {...rest}
      style={toHeadingStyleAtLevel(level, controls)}
    />
  );
}

function createHeadingStory(
  level: HeadingLevel
): TextStory<SingleHeadingStyleControls> {
  return {
    args: {
      markdown: HEADING_MARKDOWN[level],
      ...headingStyledDefaultsByLevel[level],
    },
    argTypes: createHeadingArgTypes(level),
    render: (args) => renderHeading(level, args),
  };
}

export default storyMeta('Block', 'Headings');

export const Heading1 = createHeadingStory(1);
export const Heading2 = createHeadingStory(2);
export const Heading3 = createHeadingStory(3);
export const Heading4 = createHeadingStory(4);
export const Heading5 = createHeadingStory(5);
export const Heading6 = createHeadingStory(6);
