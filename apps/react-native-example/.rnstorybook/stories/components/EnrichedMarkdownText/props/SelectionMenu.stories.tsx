import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type SelectionMenuStoryExtra = {
  copyAsMarkdownEnabled: boolean;
  copyImageUrlEnabled: boolean;
  copyLabel: string;
  copyAsMarkdownLabel: string;
  copyImageUrlLabel: string;
  copyImageUrlsLabel: string;
};

const MARKDOWN = `Select this text and open the context menu to see the built-in actions.

![Misty forest at sunrise](https://images.unsplash.com/photo-1448375240586-882707db888b?w=800)`;

const argTypes = {
  copyAsMarkdownEnabled: {
    control: 'boolean',
    description:
      'selectionMenuConfig.copyAsMarkdown.enabled — show "Copy as Markdown" in the selection menu.',
  },
  copyImageUrlEnabled: {
    control: 'boolean',
    description:
      'selectionMenuConfig.copyImageUrl.enabled — show "Copy Image URL" when the selection contains an image.',
  },
  copyLabel: {
    control: 'text',
    description: 'selectionMenuConfig.copy.label — localized label for "Copy".',
  },
  copyAsMarkdownLabel: {
    control: 'text',
    description:
      'selectionMenuConfig.copyAsMarkdown.label — localized label for "Copy as Markdown".',
  },
  copyImageUrlLabel: {
    control: 'text',
    description:
      'selectionMenuConfig.copyImageUrl.label — label for a single image.',
  },
  copyImageUrlsLabel: {
    control: 'text',
    description:
      'selectionMenuConfig.copyImageUrl.pluralLabels.other — template for multiple images ("{count}" → image count).',
  },
};

export default storyMeta('Props', 'Selection Menu');

export const Default: TextStory<SelectionMenuStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    copyAsMarkdownEnabled: true,
    copyImageUrlEnabled: true,
    // Defaults shown in Italian to demonstrate localization.
    copyLabel: 'Copia',
    copyAsMarkdownLabel: 'Copia come Markdown',
    copyImageUrlLabel: 'Copia URL immagine',
    copyImageUrlsLabel: 'Copia {count} URL immagini',
  },
  argTypes,
  render: ({
    copyAsMarkdownEnabled,
    copyImageUrlEnabled,
    copyLabel,
    copyAsMarkdownLabel,
    copyImageUrlLabel,
    copyImageUrlsLabel,
    ...args
  }) => (
    <EnrichedMarkdownTextStory
      title="Selection Menu"
      description='Built-in copy actions in the native selection menu, with localizable labels. Select text for "Copy as Markdown"; select across the image for "Copy Image URL".'
      {...args}
      selectionMenuConfig={{
        copy: { label: copyLabel },
        copyAsMarkdown: {
          enabled: copyAsMarkdownEnabled,
          label: copyAsMarkdownLabel,
        },
        copyImageUrl: {
          enabled: copyImageUrlEnabled,
          label: copyImageUrlLabel,
          pluralLabels: { other: copyImageUrlsLabel },
        },
      }}
    />
  ),
};
