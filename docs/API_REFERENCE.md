# API Reference

## EnrichedMarkdownText

### Props

### `markdown`

The Markdown content to render.

| Type     | Default Value | Platform |
| -------- | ------------- | -------- |
| `string` | Required      | Both     |

### `markdownStyle`

Style configuration for Markdown elements. See the [Style Properties Reference](STYLES.md) for a detailed overview of all available style properties.

| Type             | Default Value | Platform |
| ---------------- | ------------- | -------- |
| `MarkdownStyle`  | `{}`          | Both     |

### `containerStyle`

Style for the container view.

| Type          | Default Value | Platform |
| ------------- | ------------- | -------- |
| `ViewStyle`   | -             | Both     |

### `onLinkPress`

Callback when a link is pressed. Access URL via `event.url`.

| Type                                    | Default Value | Platform |
| --------------------------------------- | ------------- | -------- |
| `(event: LinkPressEvent) => void`       | -             | Both     |

> **Note:** For handling long-press gestures on links, see [`onLinkLongPress`](#onlinklongpress). On iOS, providing `onLinkLongPress` automatically disables the system link preview.

**Example:**

```tsx
<EnrichedMarkdownText
  markdown="Check out [React Native](https://reactnative.dev)!"
  onLinkPress={({ url }) => {
    Alert.alert('Link pressed', url);
    Linking.openURL(url);
  }}
/>
```

### `onLinkLongPress`

Callback when a link is long pressed. Access URL via `event.url`. On iOS, automatically disables the system link preview.

| Type                                         | Default Value | Platform |
| -------------------------------------------- | ------------- | -------- |
| `(event: LinkLongPressEvent) => void`       | -             | Both     |

**Example:**

```tsx
<EnrichedMarkdownText
  markdown="Check out [React Native](https://reactnative.dev)!"
  onLinkLongPress={({ url }) => {
    Alert.alert('Link long pressed', url);
  }}
/>
```

### `onTaskListItemPress`

Callback when a task list checkbox is tapped. Receives `index` (0-based), `checked` (new state after toggling), and `text` (item text).

| Type                                            | Default Value | Platform |
| ----------------------------------------------- | ------------- | -------- |
| `(event: TaskListItemPressEvent) => void`      | -             | Both     |

### `enableLinkPreview`

Controls the native link preview on long press (iOS only). Automatically set to `false` when `onLinkLongPress` is provided.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`         | iOS      |

By default, long-pressing a link on iOS shows the native system link preview. When you provide `onLinkLongPress`, the system preview is automatically disabled so your handler can fire instead.

You can also control this behavior explicitly without providing a handler:

```tsx
// Disable system link preview without providing a handler
<EnrichedMarkdownText
  markdown={content}
  enableLinkPreview={false}
/>
```

### `selectable`

Whether text can be selected.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`         | Both     |

### `selectionColor`

Color of the text selection highlight. On iOS, this also affects the caret and selection handle colors (they share a single tint). On macOS, only the selection background is affected. On Android, use `selectionHandleColor` to override the handle color independently.

| Type         | Default Value | Platform           |
| ------------ | ------------- | ------------------ |
| `ColorValue` | -             | Both, macOS, Web   |

### `selectionHandleColor`

Color of the selection handles (drag anchors). No-op on Android API levels below 29.

| Type         | Default Value | Platform |
| ------------ | ------------- | -------- |
| `ColorValue` | -             | Android  |

### `md4cFlags`

Configuration for md4c parser extension flags.

| Type          | Default Value            | Platform |
| ------------- | ------------------------ | -------- |
| `Md4cFlags`   | `{ underline: false, superscript: false, subscript: false, highlight: false, latexMath: true }` | Both |

**Properties:**

- **`underline`**: When `true`, treats `_text_` as underline instead of emphasis. When enabled, only `*text*` works for italic emphasis.
- **`superscript`**: When `true`, parses `^text^` as superscript. Visual appearance can be tuned with the `superscript` style prop — see [Superscript-specific](./STYLES.md#superscript-specific).
- **`subscript`**: When `true`, parses `~text~` as subscript. When disabled, single and double tildes remain strikethrough markers. Visual appearance can be tuned with the `subscript` style prop — see [Subscript-specific](./STYLES.md#subscript-specific).
- **`highlight`**: When `true`, parses `==text==` as highlighted spans. When disabled, double equals signs are treated as plain text. Visual appearance can be tuned with the `highlight` style prop — see [Highlight-specific](./STYLES.md#highlight-specific).
- **`latexMath`**: When `true`, parses `$...$` and `$$...$$` as LaTeX math spans.

**Example:**

```tsx
// Default: _text_ is treated as italic
<EnrichedMarkdownText
  markdown="This is _italic_ text"
/>

// With underline enabled: _text_ is underlined, *text* is italic
<EnrichedMarkdownText
  markdown="This is _underlined_ and *italic* text"
  md4cFlags={{ underline: true }}
/>
```

### `allowFontScaling`

Whether fonts should scale to respect Text Size accessibility settings.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`         | Both     |

### `maxFontSizeMultiplier`

Maximum font scale multiplier when `allowFontScaling` is enabled.

| Type     | Default Value | Platform |
| -------- | ------------- | -------- |
| `number` | `undefined`   | Both     |

### `allowTrailingMargin`

Whether to preserve the bottom margin of the last block element.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `false`        | Both     |

### `textBreakStrategy`

Controls how Android breaks lines within paragraphs. Mirrors the prop of the same name on React Native's core `Text`. The same value is used for both the measurement pass (`StaticLayout.Builder`) and the rendered `TextView`, so measured and rendered line counts stay in sync. Requires API 23+; ignored on older Android versions.

| Type                                          | Default Value   | Platform |
| --------------------------------------------- | --------------- | -------- |
| `'simple' \| 'highQuality' \| 'balanced'`     | `'highQuality'` | Android  |

- **`'simple'`**: greedy, no hyphenation; cheapest.
- **`'highQuality'`** (default): full paragraph optimization with hyphenation.
- **`'balanced'`**: balances line lengths across the paragraph; no hyphenation.

### `lineBreakStrategyIOS`

Controls iOS line-breaking refinements. Mirrors the prop of the same name on React Native's core `Text`. Maps to `NSParagraphStyle.lineBreakStrategy`. Requires iOS 14+; on earlier versions the prop is ignored.

| Type                                                       | Default Value | Platform |
| ---------------------------------------------------------- | ------------- | -------- |
| `'none' \| 'standard' \| 'hangul-word' \| 'push-out'`      | `'none'`      | iOS      |

- **`'none'`** (default): no additional line-break strategy.
- **`'standard'`**: enables the system's standard line-break refinements.
- **`'hangul-word'`**: prefers breaking at Korean word boundaries.
- **`'push-out'`**: avoids orphaned short trailing lines by pushing words to the next line.

### `writingDirection`

Paragraph writing direction. iOS only — Android already resolves direction per paragraph via the platform Bidi heuristic and is unaffected by this prop.

| Type                                            | Default Value    | Platform |
| ----------------------------------------------- | ---------------- | -------- |
| `'auto' \| 'ltr' \| 'rtl' \| 'first-strong'`    | `'first-strong'` | iOS      |

- **`'first-strong'`** (default): library extension. Each paragraph resolves its base direction from its first strong directional character — mixed Arabic/Hebrew/English documents render correctly out of the box. Paragraphs with no strong character (numbers, punctuation, block spacers) fall back to the view's Yoga-resolved layout direction, which inherits from any ancestor `<View style={{ direction: 'rtl' }}>` (defaults to `I18nManager.isRTL`). Mirrors Android's `TEXT_DIRECTION_FIRST_STRONG`.
- **`'auto'`**: React Native parity (matches `<Text writingDirection="auto">`). TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction paragraphs do not auto-resolve.
- **`'ltr'` / `'rtl'`**: forces the base direction on every paragraph in the document.

Code blocks are always rendered left-to-right regardless of this prop. Per-paragraph direction also drives list markers, blockquote borders, task-list tap targets, and the `dir` attribute emitted when copying as HTML. See [RTL Support](RTL.md) for the full behavior matrix and the copy-as-HTML caveat for mixed-direction documents.

**Example:**

```tsx
// Mixed-direction document — each paragraph picks its own side.
<EnrichedMarkdownText
  markdown={
    'هذه فقرة عربية\n\n' +
    'This English paragraph stays LTR.\n\n' +
    '123 456 789.' // neutral — follows the view's layout direction
  }
/>

// Force RTL on every paragraph regardless of content.
<EnrichedMarkdownText writingDirection="rtl" markdown={content} />
```

### `flavor`

Markdown flavor. Set to `'github'` to enable GitHub Flavored Markdown table support.

| Type                              | Default Value   | Platform |
| --------------------------------- | --------------- | -------- |
| `'commonmark' \| 'github'`        | `'commonmark'`  | Both     |

> **Note:** 
> - **`'commonmark'`**: All Markdown content is rendered as a single TextView. Selecting text will select all content in the view.
> - **`'github'`**: The Markdown AST is split into segments. Consecutive text blocks (paragraphs, headings, lists, etc.) are grouped into separate TextView segments, while tables are rendered as separate table views. This allows for granular text selection within each segment and enables interactive table features (horizontal scrolling, context menus). Text selection cannot span across segments.

### `streamingAnimation`

When `true`, newly appended content fades in during streaming updates. Only the tail (new characters beyond the previous content) is animated. Recommended for LLM streaming use cases.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `false`       | Both     |

### `streamingConfig`

Configuration for streaming behavior. Currently controls how incomplete tables are handled during streaming with `flavor="github"`.

| Type                    | Default Value            | Platform |
| ----------------------- | ------------------------ | -------- |
| `{ tableMode: string }` | `{ tableMode: 'progressive' }` | Both     |

#### `tableMode`

Controls how incomplete (still-streaming) tables are rendered:

- **`'progressive'`** (default): The table is rendered row-by-row as content arrives. Requires at least a header row and separator line before anything is shown. Incomplete trailing rows (missing closing `|` or fewer columns than the header) are trimmed. New rows fade in with animation when `streamingAnimation` is also enabled.
- **`'hidden'`**: The entire table is hidden until it is complete (followed by a blank line). This prevents visual jank from partially formed tables.

```tsx
<EnrichedMarkdownText
  markdown={streamingMarkdown}
  flavor="github"
  streamingAnimation
  streamingConfig={{ tableMode: 'hidden' }}
/>
```

### `spoilerOverlay`

Controls how spoiler text (`||hidden text||`) is displayed before being revealed.

| Type                          | Default Value | Platform |
| ----------------------------- | ------------- | -------- |
| `'particles' \| 'solid'`     | `'particles'` | Both     |

- **`'particles'`**: Animated particle overlay (CAEmitterLayer on iOS, Choreographer-driven Canvas particles on Android).
- **`'solid'`**: Opaque rectangle covering the text (Discord-style).

Both modes support tap-to-reveal.

### `contextMenuItems`

Custom items to add to the text selection context menu. Items appear before the system actions (Copy, etc.). Items with `visible: false` are hidden from the menu.

> **iOS**: Requires iOS 16+. On earlier versions the prop is ignored.

| Type                 | Default Value | Platform |
| -------------------- | ------------- | -------- |
| `ContextMenuItem[]`  | -             | Both     |

**`ContextMenuItem` shape:**

```ts
interface ContextMenuItem {
  /** Label shown in the context menu. */
  text: string;
  /**
   * SF Symbol name for the icon shown next to the item label.
   * Supported on iOS and macOS. Ignored on Android.
   * Example: 'sparkles', 'translate', 'doc.text'
   */
  icon?: string;
  /** Called when the item is tapped. */
  onPress: (event: {
    /** The selected text at the time of the press. */
    text: string;
    /** Absolute character range of the selection within the full content. */
    selection: { start: number; end: number };
  }) => void;
  /** When false, the item is not shown in the menu. Defaults to true. */
  visible?: boolean;
}
```

**Example:**

```tsx
<EnrichedMarkdownText
  markdown={content}
  contextMenuItems={[
    {
      text: 'Summarize with AI',
      onPress: ({ text }) => {
        console.log('Selected:', text);
      },
    },
    {
      text: 'Translate',
      onPress: ({ text }) => {
        translate(text);
      },
    },
  ]}
/>
```

### `selectionMenuConfig`

Controls built-in actions added to the native text selection menu. Custom app-provided actions are controlled separately with `contextMenuItems`.

| Type                 | Default Value                                  | Platform |
| -------------------- | ---------------------------------------------- | -------- |
| `SelectionMenuConfig` | `{}` (see shape below for per-field defaults) | iOS, Android, macOS |

Each item takes an object: `{ enabled }` toggles visibility (the system `copy` item can't be hidden — only relabeled) and `label` overrides the English default. The labels apply to the main text selection menu as well as the table and math block copy menus.

> **Deprecation:** the previous boolean shape (`copyAsMarkdown: false`) is still accepted at runtime for backward compatibility but logs a one-time warning. It will be removed in 0.8 — migrate to `{ enabled: false }`.

**`SelectionMenuConfig` shape:**

```ts
interface SelectionMenuConfig {
  /** System "Copy" item — can't be hidden, only relabeled. @default { label: "Copy" } */
  copy?: { label?: string };
  /** "Copy as Markdown" action. @default { enabled: true, label: "Copy as Markdown" } */
  copyAsMarkdown?: { enabled?: boolean; label?: string };
  /** "Copy Image URL" action, shown when the selection contains images. */
  copyImageUrl?: {
    enabled?: boolean;
    /** Label for a single image. @default "Copy Image URL" */
    label?: string;
    /** Forms for multiple images, chosen with Intl.PluralRules. @default { other: "Copy {count} Image URLs" } */
    pluralLabels?: SelectionMenuPluralLabels;
  };
}

interface SelectionMenuPluralLabels {
  /** CLDR plural categories. `{count}` is replaced by the image count. Missing
   *  categories fall back to `other`, so only `other` is required. */
  other: string;
  zero?: string;
  one?: string;
  two?: string;
  few?: string;
  many?: string;
}
```

**Example:**

```tsx
<EnrichedMarkdownText
  markdown={content}
  selectionMenuConfig={{
    // Hide an action:
    copyAsMarkdown: { enabled: false },
    // Localize the labels:
    copy: { label: t('copy') },
    copyImageUrl: {
      label: t('copyImageUrl'),
      pluralLabels: { other: t('copyImageUrls') }, // "{count}" → image count
    },
  }}
/>
```

See [COPY_OPTIONS.md](./COPY_OPTIONS.md#localizing-menu-labels) for details.

> **Note:** When using `flavor="github"`, `selection.start` and `selection.end` are relative to the text segment the selection is in, not the full markdown string. With `flavor="commonmark"` (default) they are always absolute within the full rendered text.

---

## EnrichedMarkdownTextInput

### Props

### `defaultValue`

Initial Markdown content for the input. The Markdown is parsed and formatting is applied on mount.

| Type     | Default Value | Platform |
| -------- | ------------- | -------- |
| `string` | -             | Both     |

### `placeholder`

Placeholder text displayed when the input is empty.

| Type     | Default Value | Platform |
| -------- | ------------- | -------- |
| `string` | -             | Both     |

### `placeholderTextColor`

Color of the placeholder text.

| Type         | Default Value | Platform |
| ------------ | ------------- | -------- |
| `ColorValue` | -             | Both     |

### `editable`

Whether the input is editable.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`        | Both     |

### `autoFocus`

Whether the input should be focused on mount.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `false`       | Both     |

### `scrollEnabled`

Whether the input is scrollable when content exceeds the visible area.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`        | Both     |

### `autoCapitalize`

Auto-capitalization behavior.

| Type     | Default Value  | Platform |
| -------- | -------------- | -------- |
| `string` | `'sentences'`  | Both     |

### `multiline`

Whether the input supports multiple lines.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`        | Both     |

### `cursorColor`

Color of the text cursor.

| Type         | Default Value | Platform |
| ------------ | ------------- | -------- |
| `ColorValue` | -             | Both     |

### `selectionColor`

Color of the text selection highlight.

| Type         | Default Value | Platform |
| ------------ | ------------- | -------- |
| `ColorValue` | -             | Both     |

### `markdownStyle`

Style configuration for formatted text in the input.

| Type                 | Default Value | Platform |
| -------------------- | ------------- | -------- |
| `MarkdownTextInputStyle` | `{}`          | Both     |

**Properties:**

- `strong.color` — text color for bold text (defaults to the input's text color).
- `em.color` — text color for italic text (defaults to the input's text color).
- `link.color` — text color for links (defaults to `#2563EB`).
- `link.underline` — whether links are underlined (defaults to `true`).
- `link.backgroundColor` — background color for links (defaults to `transparent`).
- `linkVariants` — per-URL-pattern style overrides. Each key is a regex tested against the link URL. See [Mentions — Link Variants](MENTIONS.md#link-variants-mention-styling).
- `spoiler.color` — text color for spoiler text.
- `spoiler.backgroundColor` — background color for spoiler text.

### `mentionIndicators`

List of trigger strings that start a mention flow (e.g. `['@', '#']`). See [Mentions](MENTIONS.md).

| Type       | Default Value | Platform |
| ---------- | ------------- | -------- |
| `string[]` | `[]`          | Both     |

### `style`

Style for the input view. Accepts `ViewStyle` and `TextStyle` properties (e.g., `fontSize`, `color`, `padding`).

| Type                    | Default Value | Platform |
| ----------------------- | ------------- | -------- |
| `ViewStyle \| TextStyle` | -             | Both     |

### Events

### `onChangeText`

Fires when the plain text content changes. Returns the text without Markdown syntax.

| Type                            | Default Value | Platform |
| ------------------------------- | ------------- | -------- |
| `(text: string) => void`       | -             | Both     |

### `onChangeMarkdown`

Fires when the Markdown representation changes. Returns the full Markdown string. Only active when the callback is provided — omitting it skips the serialization for better performance.

| Type                                | Default Value | Platform |
| ----------------------------------- | ------------- | -------- |
| `(markdown: string) => void`       | -             | Both     |

### `onChangeSelection`

Fires when the text selection changes.

| Type                                                  | Default Value | Platform |
| ----------------------------------------------------- | ------------- | -------- |
| `(selection: { start: number; end: number }) => void` | -             | Both     |

### `onChangeState`

Fires when the active style state changes. The payload provides a nested object for each style with an `isActive` property.

| Type                              | Default Value | Platform |
| --------------------------------- | ------------- | -------- |
| `(state: StyleState) => void`    | -             | Both     |

**`StyleState` shape:**

```ts
interface StyleState {
  bold: { isActive: boolean };
  italic: { isActive: boolean };
  underline: { isActive: boolean };
  strikethrough: { isActive: boolean };
  spoiler: { isActive: boolean };
  link: { isActive: boolean };
}
```

### `onCaretRectChange`

Fires when the caret's pixel position changes (typing, selection change, content reflow). The rect is relative to the input's top-left corner, in density-independent pixels. The native side diffs the rect before emitting, so redundant events are suppressed.

| Type                              | Default Value | Platform |
| --------------------------------- | ------------- | -------- |
| `(rect: CaretRect) => void`      | -             | Both     |

**`CaretRect` shape:**

```ts
interface CaretRect {
  x: number;
  y: number;
  width: number;
  height: number;
}
```

All values are in density-independent pixels, relative to the input's top-left corner.

**Example:**

```tsx
<EnrichedMarkdownTextInput
  scrollEnabled={false}
  onCaretRectChange={(rect) => {
    console.log('Caret at:', rect.x, rect.y);
  }}
/>
```

### `onFocus`

Fires when the input gains focus.

| Type           | Default Value | Platform |
| -------------- | ------------- | -------- |
| `() => void`   | -             | Both     |

### `onBlur`

Fires when the input loses focus.

| Type           | Default Value | Platform |
| -------------- | ------------- | -------- |
| `() => void`   | -             | Both     |

### `onStartMention`

Fires when a new mention flow starts. See [Mentions](MENTIONS.md#events).

| Type | Default Value | Platform |
| ---- | ------------- | -------- |
| `(event: { indicator: string }) => void` | - | Both |

### `onChangeMention`

Fires on every keystroke while a mention flow is active.

| Type | Default Value | Platform |
| ---- | ------------- | -------- |
| `(event: { indicator: string; text: string }) => void` | - | Both |

### `onEndMention`

Fires when the active mention flow ends.

| Type | Default Value | Platform |
| ---- | ------------- | -------- |
| `(event: { indicator: string }) => void` | - | Both |

### `writingDirection`

Paragraph writing direction in the input. iOS only — Android's `EditText` already resolves direction per paragraph via `TEXT_DIRECTION_FIRST_STRONG` and is unaffected by this prop.

| Type                                            | Default Value    | Platform |
| ----------------------------------------------- | ---------------- | -------- |
| `'auto' \| 'ltr' \| 'rtl' \| 'first-strong'`    | `'first-strong'` | iOS      |

- **`'first-strong'`** (default): each paragraph resolves its base direction from its first strong directional character. Neutral-only paragraphs fall back to the view's Yoga-resolved layout direction. Mirrors Android's platform behavior.
- **`'auto'`**: React Native parity. TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction paragraphs do not auto-resolve.
- **`'ltr'` / `'rtl'`**: forces the base direction on every paragraph in the input.

See [INPUT — RTL Support](INPUT.md#rtl-support) for caveats (placeholder direction, mixed-paragraph typing).

### `contextMenuItems`

Custom items to add to the text selection context menu. Items appear before the system actions (Copy, Cut, etc.). Items with `visible: false` are hidden from the menu.

> **iOS**: Requires iOS 16+. On earlier versions the prop is ignored.

| Type                 | Default Value | Platform |
| -------------------- | ------------- | -------- |
| `ContextMenuItem[]`  | -             | Both     |

**`ContextMenuItem` shape:**

```ts
interface ContextMenuItem {
  /** Label shown in the context menu. */
  text: string;
  /**
   * SF Symbol name for the icon shown next to the item label.
   * Supported on iOS and macOS. Ignored on Android.
   * Example: 'sparkles', 'translate', 'doc.text'
   */
  icon?: string;
  /** Called when the item is tapped. */
  onPress: (event: {
    /** The selected text at the time of the press. */
    text: string;
    /** Absolute character range of the selection within the full content. */
    selection: { start: number; end: number };
    /** Active formatting styles at the time of the press. */
    styleState: {
      bold: { isActive: boolean };
      italic: { isActive: boolean };
      underline: { isActive: boolean };
      strikethrough: { isActive: boolean };
      spoiler: { isActive: boolean };
      link: { isActive: boolean };
    };
  }) => void;
  /** When false, the item is not shown in the menu. Defaults to true. */
  visible?: boolean;
}
```

**Example:**

```tsx
<EnrichedMarkdownTextInput
  contextMenuItems={[
    {
      text: 'Summarize with AI',
      onPress: ({ text, styleState }) => {
        console.log('Selected:', text, 'Bold:', styleState.bold.isActive);
      },
    },
  ]}
/>
```

### `selectionMenuConfig`

Controls built-in items in the text selection context menu. The Format submenu and the Copy as Markdown action can each be hidden independently. Custom app-provided actions are controlled separately with `contextMenuItems`.

| Type                       | Default Value                          | Platform            |
| -------------------------- | -------------------------------------- | ------------------- |
| `InputSelectionMenuConfig` | `{ format: true, copyAsMarkdown: true }` | iOS, Android, macOS |

**`InputSelectionMenuConfig` shape:**

```ts
interface InputSelectionMenuConfig {
  /** Shows the built-in "Format" submenu (Bold, Italic, Underline, etc.). */
  format?: boolean;
  /** Shows the built-in "Copy as Markdown" action. */
  copyAsMarkdown?: boolean;
}
```

**Example:**

```tsx
// Hide both the Format submenu and the Copy as Markdown action
<EnrichedMarkdownTextInput
  selectionMenuConfig={{ format: false, copyAsMarkdown: false }}
/>

// Keep Format but hide Copy as Markdown
<EnrichedMarkdownTextInput
  selectionMenuConfig={{ copyAsMarkdown: false }}
/>
```

### `formatMenuConfig`

Controls which individual items appear inside the Format submenu. Only effective when `selectionMenuConfig.format` is `true` (the default). Omitting the prop or any field shows all items.

| Type               | Default Value                                                                        | Platform            |
| ------------------ | ------------------------------------------------------------------------------------ | ------------------- |
| `FormatMenuConfig` | `{ bold: true, italic: true, underline: true, strikethrough: true, spoiler: true, link: true }` | iOS, Android, macOS |

**`FormatMenuConfig` shape:**

```ts
interface FormatMenuConfig {
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  spoiler?: boolean;
  link?: boolean;
}
```

**Example:**

```tsx
// Hide Spoiler and Link from the Format submenu
<EnrichedMarkdownTextInput
  formatMenuConfig={{ spoiler: false, link: false }}
/>
```

### Ref Methods

All methods are called imperatively on the ref (`ref.current?.methodName()`).

### `focus()`

Focuses the input.

### `blur()`

Blurs the input.

### `setValue(markdown: string)`

Sets the input content from a Markdown string. Parses the Markdown and applies formatting.

### `getMarkdown(): Promise<string>`

Returns a Promise that resolves with the current Markdown content. The async nature is due to the native bridge — the request is sent to the native side and the result is returned via an event.

### `getCaretRect(): Promise<CaretRect>`

Returns a Promise that resolves with the current caret's pixel position relative to the input. Useful for one-off queries; for continuous tracking, prefer `onCaretRectChange`.

### `setSelection(start: number, end: number)`

Sets the text selection range.

### `toggleBold()`

Toggles bold on the current selection. When no text is selected, the style is queued and applied to the next characters typed.

### `toggleItalic()`

Toggles italic on the current selection or cursor.

### `toggleUnderline()`

Toggles underline on the current selection or cursor.

### `toggleStrikethrough()`

Toggles strikethrough on the current selection or cursor.

### `toggleSpoiler()`

Toggles spoiler on the current selection or cursor.

### `setLink(url: string)`

Applies a link URL to the currently selected text.

### `insertLink(text: string, url: string)`

Inserts a link with the given text and URL at the current cursor position. Useful when there is no text selection.

### `removeLink()`

Removes the link from the current selection.

### `startMention(indicator: string)`

Programmatically triggers a mention flow by inserting the indicator character at the current cursor position. The indicator must be listed in the `mentionIndicators` prop. Useful for toolbar buttons.

### `insertMention(displayText: string, url: string)`

Replaces the active mention token with a formatted link. Only works when a mention flow is active. The mention is serialized as `[displayText](url)` in Markdown output.

---

## Mentions

For full documentation on the mention system — setup, events, styling, and best practices — see [Mentions](MENTIONS.md).
