import {
  codegenNativeComponent,
  type ViewProps,
  type CodegenTypes,
  type ColorValue,
} from 'react-native';

// All block styles extend this interface
interface BaseBlockStyleInternal {
  fontSize: CodegenTypes.Float;
  fontFamily: string;
  fontWeight: string;
  color: ColorValue;
  marginTop: CodegenTypes.Float;
  marginBottom: CodegenTypes.Float;
  lineHeight: CodegenTypes.Float;
}

interface ParagraphStyleInternal extends BaseBlockStyleInternal {
  textAlign: string;
}

interface HeadingStyleInternal extends BaseBlockStyleInternal {
  textAlign: string;
}

interface BlockquoteStyleInternal extends BaseBlockStyleInternal {
  borderColor: ColorValue;
  borderWidth: CodegenTypes.Float;
  gapWidth: CodegenTypes.Float;
  backgroundColor: ColorValue;
}

interface ListStyleInternal extends BaseBlockStyleInternal {
  bulletColor: ColorValue;
  bulletSize: CodegenTypes.Float;
  markerMinWidth: CodegenTypes.Float;
  markerColor: ColorValue;
  markerFontWeight: string;
  gapWidth: CodegenTypes.Float;
  marginLeft: CodegenTypes.Float;
}

interface CodeBlockStyleInternal extends BaseBlockStyleInternal {
  backgroundColor: ColorValue;
  borderColor: ColorValue;
  borderRadius: CodegenTypes.Float;
  borderWidth: CodegenTypes.Float;
  padding: CodegenTypes.Float;
}

interface LinkStyleInternal {
  fontFamily: string;
  color: ColorValue;
  underline: boolean;
}

interface StrongStyleInternal {
  fontFamily: string;
  fontWeight: string;
  color?: ColorValue;
}

interface EmphasisStyleInternal {
  fontFamily: string;
  fontStyle: string;
  color?: ColorValue;
}

interface StrikethroughStyleInternal {
  color: ColorValue;
}

interface UnderlineStyleInternal {
  color: ColorValue;
}

interface CodeStyleInternal {
  fontFamily: string;
  fontSize: CodegenTypes.Float;
  color: ColorValue;
  backgroundColor: ColorValue;
  borderColor: ColorValue;
}

interface ImageStyleInternal {
  height: CodegenTypes.Float;
  borderRadius: CodegenTypes.Float;
  marginTop: CodegenTypes.Float;
  marginBottom: CodegenTypes.Float;
}

interface InlineImageStyleInternal {
  size: CodegenTypes.Float;
}

interface ThematicBreakStyleInternal {
  color: ColorValue;
  height: CodegenTypes.Float;
  marginTop: CodegenTypes.Float;
  marginBottom: CodegenTypes.Float;
}

interface TableStyleInternal extends BaseBlockStyleInternal {
  headerFontFamily: string;
  headerBackgroundColor: ColorValue;
  headerTextColor: ColorValue;
  rowEvenBackgroundColor: ColorValue;
  rowOddBackgroundColor: ColorValue;
  borderColor: ColorValue;
  borderWidth: CodegenTypes.Float;
  borderRadius: CodegenTypes.Float;
  cellPaddingHorizontal: CodegenTypes.Float;
  cellPaddingVertical: CodegenTypes.Float;
}

interface TaskListStyleInternal {
  checkedColor: ColorValue;
  borderColor: ColorValue;
  checkboxSize: CodegenTypes.Float;
  checkboxBorderRadius: CodegenTypes.Float;
  checkmarkColor: ColorValue;
  checkedTextColor: ColorValue;
  checkedStrikethrough: boolean;
}

interface MathStyleInternal {
  fontSize: CodegenTypes.Float;
  color: ColorValue;
  backgroundColor: ColorValue;
  padding: CodegenTypes.Float;
  marginTop: CodegenTypes.Float;
  marginBottom: CodegenTypes.Float;
  textAlign: string;
}

interface InlineMathStyleInternal {
  color: ColorValue;
}

interface SpoilerParticlesStyleInternal {
  density: CodegenTypes.Float;
  speed: CodegenTypes.Float;
}

interface SpoilerSolidStyleInternal {
  borderRadius: CodegenTypes.Float;
}

interface SpoilerStyleInternal {
  color: ColorValue;
  particles: SpoilerParticlesStyleInternal;
  solid: SpoilerSolidStyleInternal;
}

export interface MarkdownStyleInternal {
  paragraph: ParagraphStyleInternal;
  h1: HeadingStyleInternal;
  h2: HeadingStyleInternal;
  h3: HeadingStyleInternal;
  h4: HeadingStyleInternal;
  h5: HeadingStyleInternal;
  h6: HeadingStyleInternal;
  blockquote: BlockquoteStyleInternal;
  list: ListStyleInternal;
  codeBlock: CodeBlockStyleInternal;
  link: LinkStyleInternal;
  strong: StrongStyleInternal;
  em: EmphasisStyleInternal;
  strikethrough: StrikethroughStyleInternal;
  underline: UnderlineStyleInternal;
  code: CodeStyleInternal;
  image: ImageStyleInternal;
  inlineImage: InlineImageStyleInternal;
  thematicBreak: ThematicBreakStyleInternal;
  table: TableStyleInternal;
  taskList: TaskListStyleInternal;
  math: MathStyleInternal;
  inlineMath: InlineMathStyleInternal;
  spoiler: SpoilerStyleInternal;
}

export interface LinkPressEvent {
  url: string;
}

export interface LinkLongPressEvent {
  url: string;
}

export interface TaskListItemPressEvent {
  index: CodegenTypes.Int32;
  checked: boolean;
  text: string;
}

export interface ContextMenuItemConfig {
  text: string;
  icon?: string;
}

export interface SelectionMenuConfig {
  copyAsMarkdown: boolean;
  copyImageUrl: boolean;
}

export interface OnContextMenuItemPressEvent {
  itemText: string;
  selectedText: string;
  selectionStart: CodegenTypes.Int32;
  selectionEnd: CodegenTypes.Int32;
}

/**
 * MD4C parser flags configuration.
 * Controls how the markdown parser interprets certain syntax.
 */
export interface Md4cFlagsInternal {
  /**
   * Enable underline syntax support (__text__).
   * When enabled, underscores are treated as underline markers.
   * When disabled, underscores are treated as emphasis markers (same as asterisks).
   * @default false
   */
  underline: boolean;
  /**
   * Enable LaTeX math span parsing ($..$ and $$..$$).
   * When disabled, dollar signs are treated as plain text.
   * @default true
   */
  latexMath: boolean;
}

interface StreamingConfigInternal {
  tableMode: string;
}

export interface NativeProps extends ViewProps {
  /**
   * Markdown content to render.
   */
  markdown: string;
  /**
   * Internal style configuration for markdown elements.
   * Always provided with complete defaults via normalizeMarkdownStyle.
   * Block styles (paragraph, headings) contain fontSize, fontFamily, fontWeight, and color.
   */
  markdownStyle: MarkdownStyleInternal;
  /**
   * Callback fired when a link is pressed.
   * Receives the URL that was tapped.
   */
  onLinkPress?: CodegenTypes.BubblingEventHandler<LinkPressEvent>;
  /**
   * Callback fired when a link is long pressed.
   * Receives the URL that was long pressed.
   * - iOS: When provided, overrides the system link preview behavior.
   * - Android: Handles long press gestures on links.
   */
  onLinkLongPress?: CodegenTypes.BubblingEventHandler<LinkLongPressEvent>;
  /**
   * Callback fired when a task list checkbox is tapped.
   * Receives the 0-based task index, current checked state, and the item's plain text.
   */
  onTaskListItemPress?: CodegenTypes.BubblingEventHandler<TaskListItemPressEvent>;
  /**
   * Controls whether the system link preview is shown on long press (iOS only).
   *
   * When `true` (default), long-pressing a link shows the native iOS link preview.
   * When `false`, the system preview is suppressed.
   *
   * Automatically set to `false` when `onLinkLongPress` is provided (unless explicitly overridden).
   *
   * Android: No-op (Android doesn't have a system link preview).
   *
   * @default true
   */
  enableLinkPreview?: CodegenTypes.WithDefault<boolean, true>;
  /**
   * - iOS: Controls text selection and link previews on long press.
   * - Android: Controls text selection.
   * @default true
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
   * MD4C parser flags configuration.
   * Controls how the markdown parser interprets certain syntax.
   */
  md4cFlags: Md4cFlagsInternal;
  /**
   * Specifies whether fonts should scale to respect Text Size accessibility settings.
   * When false, text will not scale with the user's accessibility settings.
   * @default true
   */
  allowFontScaling?: CodegenTypes.WithDefault<boolean, true>;
  /**
   * Specifies the largest possible scale a font can reach when allowFontScaling is enabled.
   * Possible values:
   * - undefined/null (default): inherit from parent or global default (no limit)
   * - 0: no limit, ignore parent/global default
   * - >= 1: sets the maxFontSizeMultiplier of this node to this value
   * @default undefined
   */
  maxFontSizeMultiplier?: CodegenTypes.Float;
  /**
   * When false (default), removes trailing margin from the last element to eliminate bottom spacing.
   * When true, keeps the trailing margin from the last element's marginBottom style.
   * @default false
   */
  allowTrailingMargin?: CodegenTypes.WithDefault<boolean, false>;
  /**
   * When true, newly appended content fades in during streaming updates.
   * Only the tail (new characters beyond the previous content) is animated.
   * @default false
   */
  streamingAnimation?: CodegenTypes.WithDefault<boolean, false>;
  /**
   * Fine-grained control over streaming behavior for block-level elements.
   */
  streamingConfig?: StreamingConfigInternal;
  /**
   * Controls how spoiler text is displayed before being revealed.
   * - 'particles' (default): animated particle overlay.
   * - 'solid': opaque rectangle covering the text.
   * @default 'particles'
   */
  spoilerOverlay?: CodegenTypes.WithDefault<string, 'particles'>;

  /**
   * Custom items to show in the text selection context menu.
   */
  contextMenuItems?: ReadonlyArray<Readonly<ContextMenuItemConfig>>;
  /**
   * Built-in items to show in the text selection context menu.
   */
  selectionMenuConfig: Readonly<SelectionMenuConfig>;
  /**
   * Fired when a custom context menu item is pressed.
   * Receives the item label, the currently selected text, and the selection range.
   */
  onContextMenuItemPress?: CodegenTypes.BubblingEventHandler<OnContextMenuItemPressEvent>;
}

export default codegenNativeComponent<NativeProps>('EnrichedMarkdown', {
  interfaceOnly: true,
});
