import type { ColorValue, ViewProps, ViewStyle, TextStyle } from 'react-native';
import type { MarkdownStyle, Md4cFlags } from './MarkdownStyle';
import type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
} from './events';

/**
 * Public context menu item. Each item includes a JS-side `onPress` callback
 * that is called when the user taps the item in the selection context menu.
 */
export interface ContextMenuItem {
  text: string;
  onPress: (event: {
    text: string;
    selection: { start: number; end: number };
  }) => void;
  icon?: string;
  visible?: boolean;
}

export interface SelectionMenuConfig {
  /**
   * Shows the built-in "Copy as Markdown" action for text selections.
   * @default true
   */
  copyAsMarkdown?: boolean;
  /**
   * Shows the built-in "Copy Image URL" action when selected content contains images.
   * @default true
   */
  copyImageUrl?: boolean;
}

export interface StreamingConfig {
  /**
   * Controls how incomplete tables are handled during streaming.
   * - `'hidden'`: hide the entire table until it's complete.
   * - `'progressive'` (default): show the table row-by-row as rows complete.
   * Only effective when `streamingAnimation` is `true`.
   * @default 'progressive'
   * @platform ios, android
   */
  tableMode?: 'hidden' | 'progressive';
}

export interface EnrichedMarkdownTextProps extends Omit<ViewProps, 'style'> {
  /**
   * Markdown content to render.
   * @platform ios, android, web
   */
  markdown: string;
  /**
   * Style configuration for markdown elements.
   * @platform ios, android, web
   */
  markdownStyle?: MarkdownStyle;
  /**
   * Style for the container view.
   * @platform ios, android, web
   */
  containerStyle?: ViewStyle | TextStyle;
  /**
   * MD4C parser flags configuration.
   * Controls how the markdown parser interprets certain syntax.
   * @platform ios, android, web
   */
  md4cFlags?: Md4cFlags;
  /**
   * Callback fired when a link is pressed.
   * Receives the link URL directly.
   * @platform ios, android, web
   */
  onLinkPress?: (event: LinkPressEvent) => void;
  /**
   * Callback fired when a link is long pressed.
   * Receives the link URL directly.
   * - iOS: When provided, automatically disables the system link preview
   *   (unless `enableLinkPreview` is explicitly set to `true`).
   * - Android: Handles long press gestures on links.
   * - Web: Mapped to the `contextmenu` event (right-click).
   * @platform ios, android, web
   */
  onLinkLongPress?: (event: LinkLongPressEvent) => void;
  /**
   * Callback fired when a task list checkbox is tapped.
   *
   * The checkbox is toggled on the native side automatically.
   * Receives the 0-based task index, the new checked state (after toggling),
   * and the item's plain text.
   *
   * Only fires when `flavor="github"` (GFM task lists require GitHub flavor).
   * @platform ios, android, web
   */
  onTaskListItemPress?: (event: TaskListItemPressEvent) => void;
  /**
   * Controls whether the system link preview is shown on long press (iOS only).
   *
   * When `true`, long-pressing a link shows the native iOS link preview.
   * When `false`, the system preview is suppressed.
   *
   * Defaults to `true`, but automatically becomes `false` when `onLinkLongPress`
   * is provided. Set explicitly to override the automatic behavior.
   *
   * @default true
   * @platform ios
   */
  enableLinkPreview?: boolean;
  /**
   * Controls text selection.
   * - iOS: Controls text selection and link previews on long press.
   * - Android: Controls text selection.
   * - Web: Applies `user-select: none` when `false`.
   * @default true
   * @platform ios, android, web
   */
  selectable?: boolean;
  /**
   * Color of the text selection highlight.
   *
   * On iOS, this also affects the caret and selection handle colors
   * (they share a single tint). On macOS, only the selection background
   * is affected.
   *
   * @platform ios, android, macos, web
   */
  selectionColor?: ColorValue;
  /**
   * Color of the selection handles (drag anchors).
   * No-op on API levels below 29.
   *
   * @platform android
   */
  selectionHandleColor?: ColorValue;
  /**
   * Specifies whether fonts should scale to respect Text Size accessibility settings.
   * When false, text will not scale with the user's accessibility settings.
   * @default true
   * @platform ios, android
   */
  allowFontScaling?: boolean;
  /**
   * Specifies the largest possible scale a font can reach when `allowFontScaling`
   * is enabled.
   * - `undefined` / `null` (default): no limit
   * - `0`: no limit
   * - `>= 1`: sets the maxFontSizeMultiplier of this node to this value
   * @default undefined
   * @platform ios, android
   */
  maxFontSizeMultiplier?: number;
  /**
   * When false (default), removes trailing margin from the last element to
   * eliminate bottom spacing.
   * When true, keeps the trailing margin from the last element's marginBottom style.
   * @default false
   * @platform ios, android, web
   */
  allowTrailingMargin?: boolean;
  /**
   * Specifies which Markdown flavor to use for rendering.
   * - `'commonmark'` (default): standard CommonMark renderer (single TextView).
   * - `'github'`: GitHub Flavored Markdown — container-based renderer with
   *   support for tables and other GFM extensions.
   * @default 'commonmark'
   * @platform ios, android
   */
  flavor?: 'commonmark' | 'github';
  /**
   * When true, newly appended content fades in during streaming updates.
   * Only the tail (new characters beyond the previous content) is animated.
   * Recommended for LLM streaming use cases with `flavor="commonmark"`.
   * @default false
   * @platform ios, android
   */
  streamingAnimation?: boolean;
  /**
   * Fine-grained control over streaming behavior for block-level elements.
   * Only effective when `streamingAnimation` is `true`.
   * @platform ios, android
   */
  streamingConfig?: StreamingConfig;
  /**
   * Controls how spoiler text is displayed before being revealed.
   * - `'particles'` (default): animated particle overlay (CAEmitterLayer on iOS,
   *   Choreographer-driven Canvas particles on Android).
   * - `'solid'`: opaque rectangle covering the text (Discord-style).
   *
   * Both modes support tap-to-reveal.
   * @default 'particles'
   * @platform ios, android
   */
  spoilerOverlay?: 'particles' | 'solid';
  /**
   * Custom items to show in the text selection context menu.
   * Each item requires a `text` label and an `onPress` callback.
   * Items with `visible: false` are hidden from the menu.
   * @platform ios, android
   */
  contextMenuItems?: ContextMenuItem[];
  /**
   * Controls built-in items added to the native text selection menu.
   * Custom app-provided actions are controlled separately with `contextMenuItems`.
   * @default { copyAsMarkdown: true, copyImageUrl: true }
   * @platform ios, android, macos
   */
  selectionMenuConfig?: SelectionMenuConfig;
  /**
   * Sets the text direction on the root container.
   * Useful for RTL languages — CSS logical properties in the renderers
   * automatically flip blockquote borders, list indentation, etc.
   * @platform web
   */
  dir?: 'ltr' | 'rtl' | 'auto';
}
