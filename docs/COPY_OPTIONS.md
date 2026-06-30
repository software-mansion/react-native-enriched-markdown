# Copy Options

When text is selected, `react-native-enriched-markdown` provides enhanced copy functionality through the context menu on both platforms.

## Smart Copy

The default **Copy** action copies the selected text with rich formatting support:

### iOS

Copies in multiple formats simultaneously — receiving apps pick the richest format they support:

| Format | Description |
|--------|-------------|
| **Plain Text** | Basic text without formatting |
| **Markdown** | Original Markdown syntax preserved |
| **HTML** | Rich HTML representation |
| **RTF** | Rich Text Format for apps like Notes, Pages |
| **RTFD** | RTF with embedded images |

### Android

Copies as both **Plain Text** and **HTML** — apps that support rich text (like Gmail, Google Docs) will preserve formatting.

## Copy as Markdown

A dedicated **Copy as Markdown** option is available in the context menu on both platforms. This copies only the Markdown source text, useful when you want to preserve the original syntax.

## Copy Image URL

When selecting text that contains images, a **Copy Image URL** option appears to copy the image's source URL. On Android, if multiple images are selected, all URLs are copied (one per line).

## Controlling Built-in Menu Items

Use `selectionMenuConfig` to hide built-in selection menu actions while keeping the native menu and any `contextMenuItems` intact. Each item takes an object — `{ enabled }` toggles visibility:

```tsx
<EnrichedMarkdownText
  markdown={content}
  selectionMenuConfig={{
    copyAsMarkdown: { enabled: false },
    copyImageUrl: { enabled: false },
  }}
/>
```

`EnrichedMarkdownTextInput` supports the same prop with the legacy boolean shape. In addition to `copyAsMarkdown`, the input's `selectionMenuConfig` can hide the built-in **Format** submenu:

```tsx
<EnrichedMarkdownTextInput
  selectionMenuConfig={{
    format: false,
    copyAsMarkdown: false,
  }}
/>
```

## Localizing Menu Labels

The built-in copy actions are shown in English by default (**Copy**, **Copy as
Markdown**, **Copy Image URL**). Set a `label` on each `selectionMenuConfig` item
to translate it so it matches the rest of your app's UI — typically wired to your
i18n library:

```tsx
<EnrichedMarkdownText
  markdown={content}
  selectionMenuConfig={{
    copy: { label: t('copy') }, // "Copia"
    copyAsMarkdown: { label: t('copyAsMarkdown') }, // "Copia come Markdown"
    copyImageUrl: {
      label: t('copyImageUrl'), // "Copia URL immagine" (single image)
      pluralLabels: {
        // Forms for multiple images, chosen with Intl.PluralRules.
        other: t('copyImageUrls'), // "Copia {count} URL immagine"
      },
    },
  }}
/>
```

Notes:

- Any `label` left `undefined` keeps its English default, so you can override
  only the strings you need.
- `pluralLabels` provides the forms used when several images are selected. The
  right form is picked at runtime from the number of selected images with
  `Intl.PluralRules` (resolved against the app's default locale), keyed by CLDR
  plural category (`zero`, `one`, `two`, `few`, `many`, `other`). Only `other` is
  required; any category left `undefined` falls back to it. The `{count}` token
  is replaced by the number of selected images.
- The labels apply to the main text selection menu as well as the table and math
  block copy menus.
- The system **Copy** item on iOS/Android and OS-provided actions (Look Up,
  Translate…) are already localized by the platform and are not affected.
- Applies to `EnrichedMarkdownText`. On `EnrichedMarkdownTextInput` only the
  visibility config (`selectionMenuConfig`) is available for now.

> The simplest way to keep these in sync with the device language is to feed the
> same translation function you already use for the rest of your UI.
