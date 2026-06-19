import React from 'react';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

type AutoLinkStoryExtra = {
  autoLink: boolean;
  customRegex: string;
};

export default storyMeta('Props', 'Auto-Link');

export const Default: InputStory<AutoLinkStoryExtra> = {
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
        description='Type a URL (e.g. "google.com ") followed by a space to trigger auto-detection. Use the controls to disable detection or supply a custom regex pattern.'
        {...args}
        linkRegex={linkRegex}
      />
    );
  },
};
