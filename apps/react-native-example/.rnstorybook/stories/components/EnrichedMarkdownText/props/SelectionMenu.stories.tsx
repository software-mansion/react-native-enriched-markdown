import React from 'react';
import type {
  EnrichedMarkdownTextProps,
  TextSelectionMenuConfig,
} from 'react-native-enriched-markdown';
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

// Rich markdown that exercises every native code path the labels reach:
// the main text selection menu plus the per-segment long-press copy menus on
// the table view and the math block.
const RICH_MARKDOWN = `Select this text and open the context menu to see the built-in actions.

| Header A | Header B |
| --- | --- |
| cell 1   | cell 2   |

$$E = mc^2$$

![Misty forest at sunrise](https://images.unsplash.com/photo-1448375240586-882707db888b?w=800)`;

// Five images so a selection can include 1, 2, 3, 4, or 5 to exercise each
// slot of the precomputed `copyImageUrlPluralTemplates` array end-to-end
// (JS → Fabric struct → Android getArray → iOS array property).
const FOREST_URL =
  'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800';

const MULTI_IMAGE_MARKDOWN = `Select a range across these images to verify plural label resolution. Try 1, 2, and 5 images.

![Forest 1](${FOREST_URL})

![Forest 2](${FOREST_URL})

![Forest 3](${FOREST_URL})

![Forest 4](${FOREST_URL})

![Forest 5](${FOREST_URL})`;

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
    markdown: RICH_MARKDOWN,
    flavor: 'github',
    md4cFlags: { latexMath: true },
    copyAsMarkdownEnabled: true,
    copyImageUrlEnabled: true,
    // Italian to demonstrate localization. Long-press the table and the math
    // block to confirm the labels also reach the per-segment copy menus.
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
      description='Built-in copy actions in the native selection menu, with localizable labels. Select text for "Copy as Markdown"; select across the image for "Copy Image URL". Long-press the table and the math block to verify the per-segment copy menus pick up the same labels.'
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

// Verifies the JS-side English fallback. With no `selectionMenuConfig`,
// `normalizeItem` resolves the English defaults; native receives those strings
// and never has to fall back on its own.
export const EnglishDefaults: TextStory = {
  args: {
    markdown: RICH_MARKDOWN,
    flavor: 'github',
    md4cFlags: { latexMath: true },
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Selection Menu — English Defaults"
      description="No selectionMenuConfig prop. All copy actions (text selection, table long-press, math long-press) should show the built-in English labels: Copy / Copy as Markdown / Copy Image URL."
      {...args}
    />
  ),
};

// Polish (one/few/many/other) exercises every slot of the precomputed
// `copyImageUrlPluralTemplates` array. Selecting 1 image → `one`, 2-4 → `few`,
// 5+ → `many`; counts that fall outside 0..100 fall back to `other` natively.
export const PolishPlurals: TextStory = {
  args: {
    markdown: MULTI_IMAGE_MARKDOWN,
  },
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Selection Menu — Polish Plurals"
      description='Polish plural forms via Intl.PluralRules. Select 1 image → "Kopiuj adres URL obrazu" (one). Select 2-4 → "Kopiuj adresy URL {count} obrazów" (few). Select 5 → the many form. Exercises the precomputed copyImageUrlPluralTemplates array end-to-end.'
      {...args}
      selectionMenuConfig={{
        copy: { label: 'Kopiuj' },
        copyAsMarkdown: { label: 'Kopiuj jako Markdown' },
        copyImageUrl: {
          label: 'Kopiuj adres URL obrazu',
          pluralLabels: {
            one: 'Kopiuj adres URL obrazu',
            few: 'Kopiuj adresy URL {count} obrazów (few)',
            many: 'Kopiuj adresy URL {count} obrazów (many)',
            other: 'Kopiuj adresy URL {count} obrazów (other)',
          },
        },
      }}
    />
  ),
};

// Legacy boolean shape, accepted at runtime by `normalizeItem` for JS-only
// consumers. Should hide "Copy as Markdown" AND log a one-time deprecation
// warning. The TS surface no longer exposes the boolean, so we cast.
const deprecatedConfig = {
  copyAsMarkdown: false,
} as unknown as TextSelectionMenuConfig;

export const DeprecatedBooleanForm: TextStory = {
  args: {
    markdown:
      'Select this text. "Copy as Markdown" should be hidden and the console should log a one-time deprecation warning for selectionMenuConfig.copyAsMarkdown.',
  },
  render: (args: EnrichedMarkdownTextProps) => (
    <EnrichedMarkdownTextStory
      title="Selection Menu — Deprecated Boolean Form"
      description="Runtime compatibility shim: passing `copyAsMarkdown: false` instead of `{ enabled: false }` still works but logs a deprecation warning (removed in 0.8). Verifies the legacy path stays wired up."
      {...args}
      selectionMenuConfig={deprecatedConfig}
    />
  ),
};
