import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  fontWeightControl,
  githubFlavorArgTypes,
  tableStyledDefaults,
  type TableStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toTableStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = `| col1 | col2 | looooooooong col | a |
| - | -- | -------------------- | -------- |
| test | of | the | t |
| the | one | piece is | real
| third | Row | to test trailing | symbols | |asdf|||||blabla|`;

const argTypes = {
  ...githubFlavorArgTypes('Tables require flavor="github" (GFM).'),
  fontSize: numberControl('markdownStyle.table.fontSize', {
    min: 10,
    max: 20,
    step: 1,
  }),
  fontFamily: fontFamilyControl('markdownStyle.table.fontFamily'),
  fontWeight: fontWeightControl('markdownStyle.table.fontWeight'),
  color: {
    control: 'color',
    description: 'markdownStyle.table.color',
  },
  marginTop: numberControl('markdownStyle.table.marginTop', {
    min: 0,
    max: 48,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.table.marginBottom', {
    min: 0,
    max: 48,
    step: 2,
  }),
  lineHeight: numberControl('markdownStyle.table.lineHeight', {
    min: 14,
    max: 32,
    step: 1,
  }),
  headerFontFamily: fontFamilyControl('markdownStyle.table.headerFontFamily'),
  headerBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.table.headerBackgroundColor',
  },
  headerTextColor: {
    control: 'color',
    description: 'markdownStyle.table.headerTextColor',
  },
  rowEvenBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.table.rowEvenBackgroundColor',
  },
  rowOddBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.table.rowOddBackgroundColor',
  },
  borderColor: {
    control: 'color',
    description: 'markdownStyle.table.borderColor',
  },
  borderWidth: numberControl('markdownStyle.table.borderWidth', {
    min: 0,
    max: 4,
    step: 1,
  }),
  borderRadius: numberControl('markdownStyle.table.borderRadius', {
    min: 0,
    max: 16,
    step: 1,
  }),
  cellPaddingHorizontal: numberControl(
    'markdownStyle.table.cellPaddingHorizontal',
    { min: 4, max: 24, step: 2 }
  ),
  cellPaddingVertical: numberControl(
    'markdownStyle.table.cellPaddingVertical',
    { min: 4, max: 24, step: 2 }
  ),
};

export default storyMeta('Block', 'Table');

export const Default: TextStory<TableStyleControls> = {
  args: {
    markdown: MARKDOWN,
    flavor: 'github',
    ...tableStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, tableStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Table"
        description="GFM tables. Use the controls to tune markdownStyle.table."
        {...rest}
        style={{ table: toTableStyle(controls) }}
      />
    );
  },
};
