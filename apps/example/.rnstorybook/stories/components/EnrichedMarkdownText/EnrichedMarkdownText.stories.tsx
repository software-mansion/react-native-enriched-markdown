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
      markdown={`\
# H1
## H2
### H3
#### H4
##### H5
###### H6`}
    />
  ),
};

export const CodeBlock: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Code"
      description="Inline code with single backticks, fenced code blocks with triple backticks."
      markdown={`\
\`inline code\` and

\`\`\`
const x = 1;
console.log(x);
\`\`\``}
    />
  ),
};

export const Flavor: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Flavor"
      description="CommonMark renders as a single text view. GitHub enables table support with separate segments."
      markdown={`\
| Col A | Col B |
| ----- | ----- |
| one   | two   |
| three | four  |`}
      controls={[
        {
          prop: 'flavor',
          label: 'Flavor',
          description:
            "'commonmark': single text view - does not support tables.  \n'github': segmented with table support.",
          type: 'select',
          options: ['github', 'commonmark'],
          default: 'github',
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
      markdown={`\
_text_ and *text*

^superscript^

~subscript~`}
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

export const ThematicBreak: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Thematic Breaks"
      description="--- makes a break"
      markdown={`\
text before
---
text after`}
    />
  ),
};

export const BlockQuote: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Block Quote"
      description="'> ' creates a blockquote. You can use multiple '>' to nest the blockquotes."
      markdown={`\
> This is a blockquote.
>> Double blockquote!

> Have you heard what did she say?
yes thats crazy!`}
    />
  ),
};

export const Lists: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Lists"
      description="Unordered (- item), ordered (1. item), and nested lists. Both types can be mixed."
      markdown={`\
- Unordered item
- Another item
  - Nested unordered
  - Also nested

1. First ordered
2. Second ordered
   1. Nested ordered
   2. Still nested
3. Back to top level`}
    />
  ),
};

export const Links: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Links"
      description="[text](url) renders a tappable link. Long-press shows a preview sheet (when enabled)."
      markdown={`\
Check out [React Native](https://reactnative.dev) and [Expo](https://expo.dev).`}
      controls={[
        {
          prop: 'enableLinkPreview',
          label: 'Link preview',
          description: 'Show a preview sheet on long-press.',
          type: 'boolean',
          default: true,
        },
      ]}
    />
  ),
};

export const TaskList: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Task List"
      description="- [x] checked and - [ ] unchecked items. Tap to toggle. Requires flavor='github'."
      markdown={`\
- [x] Design component API
- [x] Write native bridge
- [ ] Add tests
- [ ] Publish to npm`}
      controls={[
        {
          prop: 'flavor',
          label: 'Flavor',
          type: 'select',
          options: ['github', 'commonmark'],
          default: 'github',
        },
      ]}
    />
  ),
};

export const Selection: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Selection"
      description="Controls text selectability and the color of the selection highlight and handles."
      markdown={`\
Select some of this text to see the highlight color in action.

You can also try **bold**, _italic_, and \`code\` spans.`}
      controls={[
        {
          prop: 'selectable',
          label: 'Selectable',
          description: 'Allow text to be selected.',
          type: 'boolean',
          default: true,
        },
        {
          prop: 'selectionColor',
          label: 'Selection color',
          description:
            'Highlight color. On iOS also sets the caret and handle color.',
          type: 'text',
          default: '',
        },
        {
          prop: 'selectionHandleColor',
          label: 'Handle color (Android)',
          description: 'Drag handle color. Android only, API 29+.',
          type: 'text',
          default: '',
        },
      ]}
    />
  ),
};

export const SelectionMenu: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="Selection Menu"
      description="Built-in actions added to the native text selection menu. Select some text to see them."
      markdown={`\
Select this text and open the context menu to see the built-in actions.

Here is some **bold** and _italic_ text, plus \`inline code\`.

![Misty forest at sunrise](https://images.unsplash.com/photo-1448375240586-882707db888b?w=800)`}
      controls={[
        {
          prop: 'selectionMenuConfig.copyAsMarkdown',
          label: 'Copy as Markdown',
          description: 'Show "Copy as Markdown" in the selection menu.',
          type: 'boolean',
          default: true,
        },
        {
          prop: 'selectionMenuConfig.copyImageUrl',
          label: 'Copy Image URL',
          description:
            'Show "Copy Image URL" when selected content contains images.',
          type: 'boolean',
          default: true,
        },
      ]}
    />
  ),
};

export const LatexMath: Story = {
  render: () => (
    <EnrichedMarkdownTextStory
      title="LaTeX Math"
      description="Inline $...$ and block $$...$$ math expressions. Toggle the flag to enable/disable parsing."
      markdown={`\
Inline: $E = mc^2$

Block:

$$
\\int_0^\\infty e^{-x}\\,dx = 1
$$`}
      controls={[
        {
          prop: 'md4cFlags.latexMath',
          label: 'LaTeX Math',
          description: 'Enable LaTeX math parsing.',
          type: 'boolean',
          default: true,
        },
      ]}
    />
  ),
};
