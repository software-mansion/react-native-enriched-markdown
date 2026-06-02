import React from 'react';
import type { ComponentProps } from 'react';
import type { Meta, StoryObj } from '@storybook/react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';
import {
  EnrichedMarkdownTextInputStory,
  MentionsStory,
  DEFAULT_MENTION_USERS,
  DEFAULT_MENTION_CHANNELS,
} from './EnrichedMarkdownTextInputStory';

const meta: Meta<typeof EnrichedMarkdownTextInput> = {
  title: 'EnrichedMarkdownTextInput',
  component: EnrichedMarkdownTextInput,
  parameters: {
    controls: { exclude: ['initialMarkdown'] },
  },
  argTypes: {
    markdownStyle: { control: 'object' },
    onChangeMarkdown: { action: 'onChangeMarkdown' },
    onChangeText: { action: 'onChangeText' },
    onFocus: { action: 'onFocus' },
    onBlur: { action: 'onBlur' },
    onLinkDetected: { action: 'onLinkDetected' },
  },
};

export default meta;
type Story = Omit<StoryObj<typeof meta>, 'args' | 'render' | 'argTypes'> & {
  args?: ComponentProps<typeof EnrichedMarkdownTextInput> & Record<string, any>;
  render: (
    args: ComponentProps<typeof EnrichedMarkdownTextInput> & Record<string, any>
  ) => React.ReactElement;
  argTypes?: Record<string, any>;
};

export const Formatting: Story = {
  args: {
    initialMarkdown:
      '**Bold**, *italic*, _underline_, ~~strikethrough~~, ||spoiler|| [link](https://example.com)',
  },
  render: (args) => (
    <EnrichedMarkdownTextInputStory
      title="Formatting"
      description="Rich text editor with a formatting toolbar. Select text or position the cursor and tap a button to apply styles."
      {...args}
    />
  ),
};

export const MarkdownStyle: Story = {
  args: {
    initialMarkdown:
      '**Bold text**, *italic text*, [a link](https://example.com), ||spoiler||',
    markdownStyle: {
      strong: { color: '#1D4ED8' },
      em: { color: '#7C3AED' },
      link: { color: '#059669', underline: true },
      spoiler: { color: '#fff', backgroundColor: '#111' },
    },
  },
  render: (args) => (
    <EnrichedMarkdownTextInputStory
      title="markdownStyle"
      description="Customize how formatted text appears inside the editor via markdownStyle. Supports strong, em, link, and spoiler."
      {...args}
    />
  ),
};

export const AutoLink: Story = {
  args: {
    initialMarkdown: '',
    autoLink: true,
    customRegex: '',
  },
  argTypes: {
    autoLink: {
      control: 'boolean',
      description:
        'Toggle auto-link detection on/off. When off, linkRegex={null} is passed and no URLs are detected.',
    },
    customRegex: {
      control: 'text',
      description:
        'Custom regex pattern string (e.g. "https?:\\/\\/[^\\s]+"). Leave empty to use the default pattern. Only used when auto-link is enabled.',
    },
  },
  render: ({ autoLink, customRegex, ...args }) => {
    let linkRegex: RegExp | null | undefined = autoLink ? undefined : null;
    if (autoLink && customRegex) {
      try {
        linkRegex = new RegExp(customRegex, 'i');
      } catch {
        linkRegex = undefined;
      }
    }
    return (
      <EnrichedMarkdownTextInputStory
        title="Auto-Link Detection"
        description={`Type a URL (e.g. "google.com ") followed by a space to trigger auto-detection. Use the controls to disable detection or supply a custom regex pattern.`}
        {...args}
        linkRegex={linkRegex}
      />
    );
  },
};

export const LinkVariants: Story = {
  args: {
    initialMarkdown:
      '[jira://PROJ-123](jira://PROJ-123), [sftp://server.example.com/file.zip](sftp://server.example.com/file.zip), [notion://page-abc](notion://page-abc), [https://example.com](https://example.com)',
    markdownStyle: {
      link: { color: '#2563EB', underline: true },
      linkVariants: {
        '^jira:': {
          color: '#0052CC',
          backgroundColor: '#DEEBFF',
          underline: false,
        },
        '^sftp:': {
          color: '#065F46',
          backgroundColor: '#D1FAE5',
          underline: false,
        },
        '^notion:': {
          color: '#6B21A8',
          backgroundColor: '#F3E8FF',
          underline: false,
        },
      },
    },
  },
  render: (args) => (
    <EnrichedMarkdownTextInputStory
      title="Link Variants"
      description="linkVariants in markdownStyle styles links differently based on their URL scheme. Each key is a regex tested against the href — first match wins. Unmatched links fall back to the base link style."
      {...args}
    />
  ),
};

export const Mentions: Story = {
  args: {
    userNames: DEFAULT_MENTION_USERS.map((u) => u.name),
    channelNames: DEFAULT_MENTION_CHANNELS.map((c) => c.name),
  },
  argTypes: {
    userNames: {
      control: 'multi-select',
      options: DEFAULT_MENTION_USERS.map((u) => u.name),
      description: 'Users available for @ mentions.',
    },
    channelNames: {
      control: 'multi-select',
      options: DEFAULT_MENTION_CHANNELS.map((c) => c.name),
      description: 'Channels available for # mentions.',
    },
  },
  render: ({ userNames, channelNames }) => (
    <MentionsStory
      title="Mentions"
      description={`Type @ to mention a user or # to mention a channel. Tap a suggestion to insert it. Toolbar buttons also trigger mention flows.\n\nMentions are styled links — linkVariants in markdownStyle maps URL patterns to custom colors.`}
      users={DEFAULT_MENTION_USERS.filter((u) => userNames?.includes(u.name))}
      channels={DEFAULT_MENTION_CHANNELS.filter((c) =>
        channelNames?.includes(c.name)
      )}
    />
  ),
};
