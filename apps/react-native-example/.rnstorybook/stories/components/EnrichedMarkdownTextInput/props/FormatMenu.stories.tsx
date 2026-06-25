import React from 'react';
import type {
  EnrichedMarkdownTextInputProps,
  FormatMenuConfig,
  InputSelectionMenuConfig,
} from 'react-native-enriched-markdown';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

type FormatMenuStoryExtra = {
  boldEnabled: boolean;
  italicEnabled: boolean;
  underlineEnabled: boolean;
  strikethroughEnabled: boolean;
  spoilerEnabled: boolean;
  linkEnabled: boolean;
  formatLabel: string;
  copyAsMarkdownLabel: string;
  boldLabel: string;
  italicLabel: string;
  underlineLabel: string;
  strikethroughLabel: string;
  spoilerLabel: string;
  linkLabel: string;
};

const MARKDOWN =
  'Select this text and open the Format submenu to see which items are visible and how their labels render.';

const argTypes = {
  boldEnabled: {
    control: 'boolean',
    description:
      'formatMenuConfig.bold.enabled — show "Bold" in the Format submenu.',
  },
  italicEnabled: {
    control: 'boolean',
    description:
      'formatMenuConfig.italic.enabled — show "Italic" in the Format submenu.',
  },
  underlineEnabled: {
    control: 'boolean',
    description:
      'formatMenuConfig.underline.enabled — show "Underline" in the Format submenu.',
  },
  strikethroughEnabled: {
    control: 'boolean',
    description:
      'formatMenuConfig.strikethrough.enabled — show "Strikethrough" in the Format submenu.',
  },
  spoilerEnabled: {
    control: 'boolean',
    description:
      'formatMenuConfig.spoiler.enabled — show "Spoiler" in the Format submenu.',
  },
  linkEnabled: {
    control: 'boolean',
    description:
      'formatMenuConfig.link.enabled — show "Link" in the Format submenu.',
  },
  formatLabel: {
    control: 'text',
    description: 'selectionMenuConfig.format.label — localized submenu title.',
  },
  copyAsMarkdownLabel: {
    control: 'text',
    description:
      'selectionMenuConfig.copyAsMarkdown.label — localized label for "Copy as Markdown".',
  },
  boldLabel: { control: 'text', description: 'formatMenuConfig.bold.label.' },
  italicLabel: {
    control: 'text',
    description: 'formatMenuConfig.italic.label.',
  },
  underlineLabel: {
    control: 'text',
    description: 'formatMenuConfig.underline.label.',
  },
  strikethroughLabel: {
    control: 'text',
    description: 'formatMenuConfig.strikethrough.label.',
  },
  spoilerLabel: {
    control: 'text',
    description: 'formatMenuConfig.spoiler.label.',
  },
  linkLabel: { control: 'text', description: 'formatMenuConfig.link.label.' },
};

export default storyMeta('Props', 'Format Menu');

export const Default: InputStory<FormatMenuStoryExtra> = {
  args: {
    initialMarkdown: MARKDOWN,
    boldEnabled: true,
    italicEnabled: true,
    underlineEnabled: true,
    strikethroughEnabled: true,
    spoilerEnabled: true,
    linkEnabled: true,
    // Italian defaults to demonstrate localization across both submenu title
    // and individual items.
    formatLabel: 'Formato',
    copyAsMarkdownLabel: 'Copia come Markdown',
    boldLabel: 'Grassetto',
    italicLabel: 'Corsivo',
    underlineLabel: 'Sottolineato',
    strikethroughLabel: 'Barrato',
    spoilerLabel: 'Spoiler',
    linkLabel: 'Collegamento',
  },
  argTypes,
  render: ({
    boldEnabled,
    italicEnabled,
    underlineEnabled,
    strikethroughEnabled,
    spoilerEnabled,
    linkEnabled,
    formatLabel,
    copyAsMarkdownLabel,
    boldLabel,
    italicLabel,
    underlineLabel,
    strikethroughLabel,
    spoilerLabel,
    linkLabel,
    ...args
  }) => (
    <EnrichedMarkdownTextInputStory
      title="Format Menu"
      description="formatMenuConfig + selectionMenuConfig control the Format submenu — items visibility and localized labels (submenu title, individual items, and 'Copy as Markdown')."
      {...args}
      selectionMenuConfig={{
        format: { label: formatLabel },
        copyAsMarkdown: { label: copyAsMarkdownLabel },
      }}
      formatMenuConfig={{
        bold: { enabled: boldEnabled, label: boldLabel },
        italic: { enabled: italicEnabled, label: italicLabel },
        underline: { enabled: underlineEnabled, label: underlineLabel },
        strikethrough: {
          enabled: strikethroughEnabled,
          label: strikethroughLabel,
        },
        spoiler: { enabled: spoilerEnabled, label: spoilerLabel },
        link: { enabled: linkEnabled, label: linkLabel },
      }}
    />
  ),
};

// Omit both configs — verifies the JS-side English fallback resolves to the
// built-in defaults across iOS, Android, and macOS.
export const EnglishDefaults: InputStory = {
  args: {
    initialMarkdown: MARKDOWN,
  },
  render: (args) => (
    <EnrichedMarkdownTextInputStory
      title="Format Menu — English Defaults"
      description="No selectionMenuConfig / formatMenuConfig. Submenu title, items, and 'Copy as Markdown' should all show their English defaults: Format / Bold / Italic / Underline / Strikethrough / Spoiler / Link / Copy as Markdown."
      {...args}
    />
  ),
};

// Legacy boolean form (`bold: false`) — accepted by the runtime shim and
// logs a one-time warnOnce. Removed in 0.8. Cast through unknown because
// the TS surface no longer exposes the boolean shape.
const deprecatedFormatConfig = {
  bold: false,
} as unknown as FormatMenuConfig;

const deprecatedSelectionConfig = {
  copyAsMarkdown: false,
} as unknown as InputSelectionMenuConfig;

export const DeprecatedBooleanForm: InputStory = {
  args: {
    initialMarkdown:
      'Select this text. "Bold" should be hidden inside Format, "Copy as Markdown" should be missing, and the console should log one-time deprecation warnings for both.',
  },
  render: (args: EnrichedMarkdownTextInputProps) => (
    <EnrichedMarkdownTextInputStory
      title="Format Menu — Deprecated Boolean Form"
      description="Runtime compatibility shim: passing `bold: false` / `copyAsMarkdown: false` (instead of `{ enabled: false }`) still works but logs deprecation warnings. Removed in 0.8."
      {...args}
      selectionMenuConfig={deprecatedSelectionConfig}
      formatMenuConfig={deprecatedFormatConfig}
    />
  ),
};
