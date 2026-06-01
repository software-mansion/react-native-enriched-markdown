import React from 'react';
import type { ComponentProps } from 'react';
import type { Meta, StoryObj } from '@storybook/react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import {
  EnrichedMarkdownTextStory,
  SpoilerStory,
} from './EnrichedMarkdownTextStory';

const meta: Meta<typeof EnrichedMarkdownText> = {
  title: 'EnrichedMarkdownText',
  component: EnrichedMarkdownText,
  parameters: {
    controls: { exclude: ['markdown'] },
  },
  argTypes: {
    style: { control: 'object' },
    onLinkPress: { name: 'onLinkPress', action: 'onLinkPress' },
    onLinkLongPress: { name: 'onLinkLongPress', action: 'onLinkLongPress' },
    onTaskListItemPress: {
      name: 'onTaskListItemPress',
      action: 'onTaskListItemPress',
    },
  },
};

export default meta;
type Story = Omit<StoryObj<typeof meta>, 'args' | 'render' | 'argTypes'> & {
  args?: ComponentProps<typeof EnrichedMarkdownText> & Record<string, any>;
  render: (
    args: ComponentProps<typeof EnrichedMarkdownText> & Record<string, any>
  ) => React.ReactElement;
  argTypes?: Record<string, any>;
};

export const InlineMarkdown: Story = {
  args: {
    markdown:
      '**Bold**, *italic*, ***bold italic***, ~~strikethrough~~, `inline code`, [link](https://example.com)',
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Inline Markdown"
      description="Renders inline markdown: bold, italic, strikethrough, and more."
      {...args}
    />
  ),
};

export const Headings: Story = {
  args: {
    markdown: '# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6',
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Headings"
      description="Supports all six heading levels via # syntax."
      {...args}
    />
  ),
};

export const CodeBlock: Story = {
  args: {
    markdown: '`inline code` and\n\n```\nconst x = 1;\nconsole.log(x);\n```',
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Code"
      description="Inline code with single backticks, fenced code blocks with triple backticks."
      {...args}
    />
  ),
};

export const Table: Story = {
  args: {
    markdown:
      '| Col A | Col B |\n| ----- | ----- |\n| one   | two   |\n| three | four  |',
    flavor: 'github',
  },
  argTypes: {
    flavor: {
      options: ['github', 'commonmark'],
      control: { type: 'inline-radio' },
    },
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Table"
      description="Tables are renderable only via GitHub flavor. With commonmark it does not render."
      {...args}
    />
  ),
};

export const Md4cFlags: Story = {
  args: {
    markdown: '_underline_\n\ntext^superscript^\n\ntext~subscript~',
    underline: true,
    superscript: true,
    subscript: true,
  },
  argTypes: {
    underline: {
      label: 'Underline',
      control: 'boolean',
      description: 'When on, _text_ = underline. Only *text* works for italic.',
    },
    superscript: {
      label: 'Superscript',
      control: 'boolean',
      description: '^text^ renders as superscript.',
    },
    subscript: {
      label: 'Subscript',
      control: 'boolean',
      description:
        '~text~ renders as subscript. When off, single tilde is strikethrough.',
    },
  },
  render: ({ underline, superscript, subscript, ...args }) => (
    <EnrichedMarkdownTextStory
      title="md4cFlags"
      description="Parser extension flags for extended Markdown syntax."
      {...args}
      md4cFlags={{ underline, superscript, subscript }}
    />
  ),
};

export const Spoiler: Story = {
  args: {
    markdown: "The twist: ||the butler did it||. Don't spoil it.",
    overlay: 'particles',
  },
  argTypes: {
    overlay: {
      options: ['particles', 'solid'],
      control: { type: 'inline-radio' },
    },
    onReloadSpoiler: { action: 'onReloadSpoiler' },
  },
  render: (args) => (
    <SpoilerStory
      title="Spoiler"
      description="||hidden text|| is concealed until tapped. Use 'Reload Spoiler' to reset the overlay."
      {...args}
    />
  ),
};

export const ThematicBreak: Story = {
  args: {
    markdown: 'text before\n\n---\n\ntext after',
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Thematic Breaks"
      description="--- makes a break"
      {...args}
    />
  ),
};

export const BlockQuote: Story = {
  args: {
    markdown:
      '> This is a blockquote.\n>> Double blockquote!\n\n> Have you heard what did she say?\n\nyes thats crazy!',
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Block Quote"
      description="'> ' creates a blockquote. You can use multiple '>' to nest the blockquotes."
      {...args}
    />
  ),
};

export const Lists: Story = {
  args: {
    markdown:
      '- Unordered item\n- Another item\n  - Nested unordered\n  - Also nested\n\n1. First ordered\n2. Second ordered\n   1. Nested ordered\n   2. Still nested\n3. Back to top level',
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Lists"
      description="Unordered (- item), ordered (1. item), and nested lists. Both types can be mixed."
      {...args}
    />
  ),
};

export const Links: Story = {
  args: {
    markdown:
      'Check out [React Native](https://reactnative.dev) and [Expo](https://expo.dev).',
    preview: true,
  },
  argTypes: {
    preview: {
      control: 'boolean',
      description: 'Show a preview sheet on long-press.',
    },
  },
  render: ({ preview, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Links"
      description={`[text](url) renders a tappable link. Long-press shows a preview sheet (when enabled, iOS only - Android has no native link preview).\n\nNote: selectionHandleColor has no effect on iOS (Android-only, API 29+).`}
      {...args}
      enableLinkPreview={preview}
    />
  ),
};

export const TaskList: Story = {
  args: {
    markdown:
      '- [x] Design component API\n- [x] Write native bridge\n- [ ] Add tests\n- [ ] Publish to npm',
    flavor: 'github',
  },
  argTypes: {
    flavor: {
      label: 'Flavor',
      options: ['github', 'commonmark'],
      control: { type: 'inline-radio' },
      description:
        'Task lists require flavor="github" (GFM). commonmark renders them as plain list items.',
    },
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Task List"
      description="- [x] checked and - [ ] unchecked items. Tap to toggle."
      {...args}
    />
  ),
};

export const Selection: Story = {
  args: {
    markdown:
      'Select some of this text to see the highlight color in action.\n\nYou can also try **bold**, _italic_, and `code` spans.',
    selectable: true,
  },
  argTypes: {
    selectable: {
      control: 'boolean',
      description: 'Allow text to be selected.',
    },
    selColor: {
      control: 'color',
      description:
        'Highlight color. On iOS also sets the caret and handle color.',
    },
    handleColor: {
      control: 'color',
      description: 'Drag handle color. Android only, API 29+.',
    },
  },
  render: ({ selColor, handleColor, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Selection"
      description="Controls text selectability and the color of the selection highlight and handles."
      {...args}
      selectionColor={selColor}
      selectionHandleColor={handleColor}
    />
  ),
};

export const SelectionMenu: Story = {
  args: {
    markdown:
      'Select this text and open the context menu to see the built-in actions.\n\nHere is some **bold** and _italic_ text, plus `inline code`.\n\n![Misty forest at sunrise](https://images.unsplash.com/photo-1448375240586-882707db888b?w=800)',
    copyMd: true,
    imgUrl: true,
  },
  argTypes: {
    copyMd: {
      control: 'boolean',
      description: 'Show "Copy as Markdown" in the selection menu.',
    },
    imgUrl: {
      control: 'boolean',
      description:
        'Show "Copy Image URL" when selected content contains images.',
    },
  },
  render: ({ copyMd, imgUrl, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Selection Menu"
      description="Built-in actions added to the native text selection menu. Select some text to see them."
      {...args}
      selectionMenuConfig={{ copyAsMarkdown: copyMd, copyImageUrl: imgUrl }}
    />
  ),
};

export const LatexMath: Story = {
  args: {
    markdown:
      'Inline: $E = mc^2$\n\nBlock:\n\n$$\n\\int_0^\\infty e^{-x}\\,dx = 1\n$$\n',
    latexMath: true,
    flavor: 'github',
  },
  argTypes: {
    latexMath: {
      label: 'LaTeX math',
      control: 'boolean',
      description: 'Enable LaTeX math parsing.',
    },
  },
  render: ({ latexMath, ...args }) => (
    <EnrichedMarkdownTextStory
      title="LaTeX Math"
      description="Inline $...$ and block $$...$$ math expressions. Toggle the flag to enable/disable parsing."
      {...args}
      md4cFlags={{ latexMath }}
    />
  ),
};
