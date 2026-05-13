import React from 'react';
import type {Meta, StoryObj} from '@storybook/react-native';
import {EnrichedMarkdownText} from 'react-native-enriched-markdown';
import {EnrichedMarkdownTextStory} from './EnrichedMarkdownTextStory';

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
