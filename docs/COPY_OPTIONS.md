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

Use `selectionMenuConfig` to hide built-in selection menu actions while keeping the native menu and any `contextMenuItems` intact:

```tsx
<EnrichedMarkdownText
  markdown={content}
  selectionMenuConfig={{
    copyAsMarkdown: false,
    copyImageUrl: false,
  }}
/>
```
