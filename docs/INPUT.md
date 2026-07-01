# EnrichedMarkdownTextInput

`EnrichedMarkdownTextInput` is a rich text input component that outputs Markdown. It is an uncontrolled input — it doesn't use any state or props to store its value, but instead directly interacts with the underlying platform-specific components. Thanks to this, the component is really performant and simple to use.

## Usage

Here's a simple example of an input that lets you toggle bold on its text and shows whether bold is currently active via the button color.

```tsx
import { useRef, useState } from 'react';
import { View, Button, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        placeholder="Type here..."
        onChangeState={setState}
        style={styles.input}
      />
      <View style={styles.toolbar}>
        <Button
          title={state?.bold.isActive ? 'Unbold' : 'Bold'}
          color={state?.bold.isActive ? 'green' : 'gray'}
          onPress={() => ref.current?.toggleBold()}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  input: { width: '100%', fontSize: 20, padding: 10, maxHeight: 200, backgroundColor: 'lightgray' },
  toolbar: { flexDirection: 'row', gap: 8, marginTop: 8 },
});
```

Summary of what happens here:

1. Any methods imperatively called on the input to e.g. toggle some style must be used through a `ref` of `EnrichedMarkdownTextInputInstance` type. Here, `toggleBold` method that is called on the button press calls `ref.current?.toggleBold()`, which toggles the bold styling within the current selection.
2. All style state information is emitted by the `onChangeState` callback. The callback payload provides a nested object for each style (e.g., `bold`, `italic`), containing an `isActive` property to guide your UI logic — indicating if the style is currently applied (highlight the button).

## Inline Styles

Supported styles:

- bold
- italic
- underline
- strikethrough
- spoiler

Each of the styles can be toggled the same way as in the example from [usage section](#usage); call a proper `toggle` function on the component ref.

Each call toggles the style within the current text selection. They are being toggled on exactly the character range that is currently selected. When toggling the style with just the cursor in place (no selection), the style is ready to be used and will be applied to the next characters that the user inputs.

Styles are also available through the built-in native format bar that appears on text selection, and through the system context menu.

## Links

Links are a piece of text with a URL attributed to it. They can be managed by calling methods on the input ref:

- [`setLink(url)`](API_REFERENCE.md#setlinkurl-string) — applies a link to the currently selected text.
- [`insertLink(text, url)`](API_REFERENCE.md#insertlinktext-string-url-string) — inserts a new link at the cursor position with the given text and URL. Useful when there is no selection.
- [`removeLink()`](API_REFERENCE.md#removelink) — removes the link from the current selection.

The built-in native format bar also includes a link option that presents a URL prompt when text is selected.

A complete example of a setup that supports both setting links on the selected text, as well as inserting them at the cursor position can be found in the example app code.

## Auto-Link Detection

`EnrichedMarkdownTextInput` can automatically detect URLs as the user types and convert them into Markdown links. Detected links are visually styled in the input and serialized as `[text](url)` in the Markdown output.

### Basic usage

Auto-link detection is enabled by default. URLs like `google.com`, `www.google.com`, and `https://google.com` are detected when followed by a space or newline.

Bare domains and `www.` prefixes are automatically normalized with `https://` (e.g., `google.com` becomes `[google.com](https://google.com)`).

### Custom regex

You can provide a custom regex pattern to control which text is detected as a link:

```tsx
<EnrichedMarkdownTextInput
  linkRegex={/https?:\/\/[^\s]+/i}
/>
```

Pass `null` to disable auto-link detection entirely:

```tsx
<EnrichedMarkdownTextInput linkRegex={null} />
```

### Listening for detections

Use the `onLinkDetected` callback to be notified when a new link is detected:

```tsx
<EnrichedMarkdownTextInput
  onLinkDetected={({ text, url, start, end }) => {
    console.log(`Detected link: ${text} -> ${url} at [${start}, ${end}]`);
  }}
/>
```

The callback fires only for newly detected links — not for links that were already detected and remain unchanged.

### Interaction with manual links

When a manual link is applied (via `setLink` or `insertLink`) over an auto-detected link, the auto-detected link is replaced by the manual one. Auto-link detection skips ranges that already contain a manual link.

## Caret Position Tracking

`EnrichedMarkdownTextInput` can report the caret's pixel position relative to the input, which is useful when the input is embedded in a scrollable container with `scrollEnabled={false}` and you need to keep the caret visible.

### `onCaretRectChange`

A push-based callback that fires whenever the caret moves (typing, selection change, content reflow). The native side diffs the caret rect before emitting, so redundant events are suppressed automatically.

```tsx
<EnrichedMarkdownTextInput
  scrollEnabled={false}
  onCaretRectChange={(rect) => {
    console.log(rect);
  }}
/>
```

### `getCaretRect()`

An imperative, pull-based method for one-off queries. Returns a Promise that resolves with the current caret rect.

```tsx
const rect = await ref.current?.getCaretRect();
```

## Mentions

`EnrichedMarkdownTextInput` supports mention flows with configurable trigger indicators, lifecycle events for showing suggestion lists, and per-pattern styling via `linkVariants`.

See [Mentions](MENTIONS.md) for full documentation on setup, events, ref methods, and styling.

## Clipboard

The input's content can be copied to the system clipboard from a ref, without requiring the user to select text and open the context menu:

- [`copyToClipboard()`](API_REFERENCE.md#copytoclipboard) — copies the full content to the system clipboard, matching the result of selecting all text and pressing the context menu's copy action. The selection is left unchanged, and calling it on an empty input is a no-op.

On iOS and macOS the clipboard receives both plain text and a private Markdown pasteboard type, so pasting back into an `EnrichedMarkdownTextInput` restores the formatting; external apps receive plain text only. On Android the clipboard receives plain text only — inline styles are not preserved for any paste target.

## Style Detection

All of the above styles can be detected with the use of [onChangeState](API_REFERENCE.md#onchangestate) callback payload.

You can find some examples in the [usage section](#usage) or in the example app.

## Other Events

`EnrichedMarkdownTextInput` emits a few more events that may be of use:

- [onFocus](API_REFERENCE.md#onfocus-1) - emits whenever input focuses.
- [onBlur](API_REFERENCE.md#onblur) - emits whenever input blurs.
- [onChangeText](API_REFERENCE.md#onchangetext) - returns the input's plain text (without Markdown syntax) anytime it changes.
- [onChangeMarkdown](API_REFERENCE.md#onchangemarkdown) - returns the Markdown string parsed from current input text and styles anytime it would change. As parsing the Markdown on each input change can be expensive, not assigning the event's callback will skip the serialization for better performance.
- [onChangeSelection](API_REFERENCE.md#onchangeselection) - returns `{ start, end }` of the current selection, useful for working with [links](#links).

## RTL Support

`EnrichedMarkdownTextInput` resolves writing direction **per paragraph**, matching the read-only [`EnrichedMarkdownText`](RTL.md) renderer. Arabic, Hebrew, and Persian content right-aligns automatically as the user types — even mixed with English paragraphs in the same input.

### Platform setup

No setup is required. Both platforms autodetect direction per paragraph out of the box.

- **Android** — `EditText` resolves direction per paragraph via `View.TEXT_DIRECTION_FIRST_STRONG` (the platform default). The [`writingDirection`](#writingdirection-prop-ios) prop is accepted but has no effect.
- **iOS** — TextKit's `NSWritingDirectionNatural` follows the app's global UI layout direction and does not do per-paragraph first-strong. The library applies first-strong itself after every formatting pass. The mode is controlled by [`writingDirection`](#writingdirection-prop-ios) and defaults to `'first-strong'`.

### `writingDirection` prop (iOS)

| Value | Behavior |
|---|---|
| `'first-strong'` (default) | Per-paragraph autodetection. Neutral-only paragraphs fall back to the view's resolved layout direction. Matches Android. |
| `'auto'` | React Native parity. TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction documents do not auto-resolve. |
| `'ltr'` | Forces LTR on every paragraph. |
| `'rtl'` | Forces RTL on every paragraph. |

```tsx
<EnrichedMarkdownTextInput writingDirection="rtl" placeholder="اكتب هنا..." />
```

### Known limitations

- **Placeholder** follows the host view's layout direction, not the prop. If you need an RTL placeholder, wrap the input in `<View style={{ direction: 'rtl' }}>` or set `I18nManager.forceRTL(true)`.
- **Mixed paragraphs while typing** — newly inserted characters in an empty paragraph briefly inherit the previous paragraph's direction; the first-strong pass corrects this on the next input event.
- **Code blocks, tables, blockquotes, lists** are not supported in the input (it's a flat inline-formatting surface). For those, use [`EnrichedMarkdownText`](TEXT.md).

See [RTL Support](RTL.md) for the full per-element behavior on the rendered output side.

## Customizing \<EnrichedMarkdownTextInput /> Styles

`EnrichedMarkdownTextInput` accepts a `markdownStyle` prop for customizing how formatted text appears in the input:

```tsx
<EnrichedMarkdownTextInput
  markdownStyle={{
    strong: { color: '#1D4ED8' },
    em: { color: '#7C3AED' },
    link: { color: '#2563EB', underline: true },
  }}
/>
```

Available style properties:

- `strong.color` — text color for bold text (defaults to the input's text color).
- `em.color` — text color for italic text (defaults to the input's text color).
- `link.color` — text color for links (defaults to `#2563EB`).
- `link.underline` — whether links are underlined (defaults to `true`).
- `spoiler.color` — text color for spoiler text.
- `spoiler.backgroundColor` — background color for spoiler text.
