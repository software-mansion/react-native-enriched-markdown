import React from 'react';
import type { Meta, StoryObj } from '@storybook/react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { EnrichedMarkdownTextStory } from './EnrichedMarkdownTextStory';

const meta = {
  title: 'EnrichedMarkdownText',
  component: EnrichedMarkdownText,
} satisfies Meta<typeof EnrichedMarkdownText>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Basic: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Basic"
      description="Renders inline markdown: bold, italic, strikethrough, and more."
      markdown="**Bold**, _italic_, ~~strikethrough~~, `code`"
    />
  ),
};

export const Headings: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Headings"
      description="Supports all six heading levels via # syntax."
      markdown={'# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6'}
    />
  ),
};

export const CodeBlock: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Code"
      description="Inline code with single backticks, fenced code blocks with triple backticks."
      markdown={'`inline code` and\n\n```\nconst x = 1;\nconsole.log(x);\n```'}
    />
  ),
};

export const Flavor: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Flavor"
      description="CommonMark renders as a single text view. GitHub enables table support with separate segments."
      markdown={
        '| Col A | Col B |\n| ----- | ----- |\n| one   | two   |\n| three | four  |'
      }
      controls={[
        {
          prop: 'flavor',
          label: 'Flavor',
          description:
            "'commonmark': single text view.  'github': segmented with table support.",
          type: 'select',
          options: ['commonmark', 'github'],
          default: 'commonmark',
        },
      ]}
    />
  ),
};

export const Md4cFlags: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="md4cFlags"
      description="Parser extension flags for extended Markdown syntax."
      markdown={'_text_ and *text*\n\n^superscript^\n\n~subscript~'}
      controls={[
        {
          prop: 'md4cFlags.underline',
          label: 'Underline mode',
          description:
            'When on, _text_ = underline. Only *text* works for italic.',
          type: 'boolean',
          default: false,
        },
        {
          prop: 'md4cFlags.superscript',
          label: 'Superscript',
          description: '^text^ renders as superscript.',
          type: 'boolean',
          default: false,
        },
        {
          prop: 'md4cFlags.subscript',
          label: 'Subscript',
          description:
            '~text~ renders as subscript. When off, single tilde is strikethrough.',
          type: 'boolean',
          default: false,
        },
      ]}
    />
  ),
};

export const Spoiler: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Spoiler"
      description="||hidden text|| is concealed until tapped."
      markdown="The twist: ||the butler did it||. Don't spoil it."
      controls={[
        {
          prop: 'spoilerOverlay',
          label: 'Overlay style',
          description:
            "'particles': animated overlay. \n'solid': opaque block (Discord-style).",
          type: 'select',
          options: ['particles', 'solid'],
          default: 'particles',
        },
      ]}
    />
  ),
};
