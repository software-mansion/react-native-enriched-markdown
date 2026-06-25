import { useMemo, useCallback, useRef, useEffect } from 'react';
import EnrichedMarkdownTextNativeComponent from '../EnrichedMarkdownTextNativeComponent';
import type { MarkdownStyleInternal } from '../EnrichedMarkdownTextNativeComponent';
import EnrichedMarkdownNativeComponent from '../EnrichedMarkdownNativeComponent';
import { normalizeMarkdownStyle } from '../normalizeMarkdownStyle';
import type { NativeSyntheticEvent } from 'react-native';
import type { MarkdownStyle, Md4cFlags } from '../types/MarkdownStyle';
import type {
  EnrichedMarkdownTextProps,
  StreamingConfig,
  ContextMenuItem,
  SelectionMenuConfig,
  SelectionMenuPluralLabels,
} from '../types/MarkdownTextProps';
import type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
  OnContextMenuItemPressEvent,
} from '../types/events';

export type { MarkdownStyle, Md4cFlags };
export type {
  EnrichedMarkdownTextProps,
  StreamingConfig,
  ContextMenuItem,
  SelectionMenuConfig,
  SelectionMenuPluralLabels,
};
export type { LinkPressEvent, LinkLongPressEvent, TaskListItemPressEvent };

// Default English labels for the built-in selection menu actions. Defaults are
// resolved here (JS-side) so the native code always receives a concrete string.
const DEFAULT_COPY_LABEL = 'Copy';
const DEFAULT_COPY_AS_MARKDOWN_LABEL = 'Copy as Markdown';
const DEFAULT_COPY_IMAGE_URL_LABEL = 'Copy Image URL';
const DEFAULT_COPY_IMAGE_URLS_LABEL = 'Copy {count} Image URLs';

/**
 * Resolves `pluralLabels` into a per-count template table (index = image count,
 * 0..100) the native side can index without any locale logic. `Intl.PluralRules`
 * selects the CLDR category for each count; missing categories fall back to the
 * required `other`. Index 1 uses the singular `label` (the single-image case).
 * Native uses `other` (copyImageUrlsLabel) for counts > 100, and falls back to
 * the singular/`{count}` templates entirely when this returns an empty array
 * (no plural labels set, or `Intl.PluralRules` unavailable).
 */
const buildPluralTemplates = (
  pluralLabels: SelectionMenuPluralLabels | undefined,
  singularLabel: string
): string[] => {
  if (!pluralLabels) return [];

  const IntlRef = Intl as unknown as {
    PluralRules?: new (locales?: string | string[]) => {
      select(n: number): string;
    };
  };
  if (typeof IntlRef.PluralRules !== 'function') return [];

  let pluralRules: { select(n: number): string };
  try {
    // TODO: expose `copyImageUrl.pluralLocale?: string` so i18n apps can force
    // a locale independent of the device. Today this resolves to the JS
    // runtime's default locale, so on an English device only `one` and `other`
    // ever fire even when richer plural labels are configured.
    pluralRules = new IntlRef.PluralRules();
  } catch {
    return [];
  }

  const { other } = pluralLabels;
  const byCategory: Record<string, string> = {
    zero: pluralLabels.zero ?? other,
    one: pluralLabels.one ?? other,
    two: pluralLabels.two ?? other,
    few: pluralLabels.few ?? other,
    many: pluralLabels.many ?? other,
    other,
  };

  const templates: string[] = [];
  for (let n = 0; n <= 100; n++) {
    // The literal single-image case uses the (non-plural) singular label; every
    // other count uses its CLDR category form.
    templates.push(
      n === 1 ? singularLabel : (byCategory[pluralRules.select(n)] ?? other)
    );
  }
  return templates;
};

// One-time deprecation warnings for the legacy boolean shape of
// selectionMenuConfig items. Not __DEV__-gated on purpose: deprecation warnings
// need to surface in staging/TestFlight/CI prod builds too.
const warned = new Set<string>();
const warnOnce = (key: string, msg: string) => {
  if (warned.has(key)) return;
  warned.add(key);
  console.warn(msg);
};

type NormalizedMenuItem = { enabled: boolean; label: string };

/**
 * Normalizes a `selectionMenuConfig` item to `{ enabled, label }`, resolving the
 * English default label JS-side. Accepts the legacy boolean form at runtime
 * (deprecated, removed in 0.8) so JS-only consumers don't silently break.
 */
const normalizeItem = (
  raw: unknown,
  field: string,
  defaultEnabled: boolean,
  defaultLabel: string
): NormalizedMenuItem => {
  if (raw === undefined)
    return { enabled: defaultEnabled, label: defaultLabel };
  if (typeof raw === 'boolean') {
    warnOnce(
      `selectionMenuConfig.${field}`,
      `[react-native-enriched-markdown] selectionMenuConfig.${field} as a boolean is ` +
        `deprecated; use { enabled: ${raw} }. The boolean form will be removed in 0.8.`
    );
    return { enabled: raw, label: defaultLabel };
  }
  const obj = raw as { enabled?: boolean; label?: string };
  return {
    enabled: obj.enabled ?? defaultEnabled,
    label: obj.label ?? defaultLabel,
  };
};

const defaultMd4cFlags: Md4cFlags = {
  underline: false,
  superscript: false,
  subscript: false,
  latexMath: true,
  highlight: false,
};

export const EnrichedMarkdownText = ({
  markdown,
  markdownStyle = {},
  containerStyle,
  onLinkPress,
  onLinkLongPress,
  onTaskListItemPress,
  enableLinkPreview,
  selectable = true,
  md4cFlags = defaultMd4cFlags,
  allowFontScaling = true,
  maxFontSizeMultiplier,
  allowTrailingMargin = false,
  flavor = 'commonmark',
  streamingAnimation = false,
  streamingConfig,
  spoilerOverlay = 'particles',
  contextMenuItems,
  selectionMenuConfig,
  selectionColor,
  selectionHandleColor,
  textBreakStrategy,
  lineBreakStrategyIOS,
  writingDirection = 'first-strong',
  ...rest
}: EnrichedMarkdownTextProps) => {
  const normalizedStyleRef = useRef<MarkdownStyleInternal | null>(null);
  const normalized = normalizeMarkdownStyle(markdownStyle);
  // normalizeMarkdownStyle returns cached objects for structurally equal inputs,
  // so this referential check is sufficient to preserve a stable prop reference.
  if (normalizedStyleRef.current !== normalized) {
    normalizedStyleRef.current = normalized;
  }
  const normalizedStyle = normalizedStyleRef.current!;

  const normalizedMd4cFlags = useMemo(
    () => ({
      underline: md4cFlags.underline ?? false,
      superscript: md4cFlags.superscript ?? false,
      subscript: md4cFlags.subscript ?? false,
      latexMath: md4cFlags.latexMath ?? true,
      highlight: md4cFlags.highlight ?? false,
    }),
    [md4cFlags]
  );

  const contextMenuCallbacksRef = useRef<
    Map<string, ContextMenuItem['onPress']>
  >(new Map());

  useEffect(() => {
    const callbacksMap = new Map<string, ContextMenuItem['onPress']>();
    if (contextMenuItems) {
      for (const item of contextMenuItems) {
        callbacksMap.set(item.text, item.onPress);
      }
    }
    contextMenuCallbacksRef.current = callbacksMap;
  }, [contextMenuItems]);

  const nativeContextMenuItems = useMemo(
    () =>
      contextMenuItems
        ?.filter((item) => item.visible !== false)
        .map((item) => ({ text: item.text, icon: item.icon })),
    [contextMenuItems]
  );

  const handleContextMenuItemPress = useCallback(
    (e: NativeSyntheticEvent<OnContextMenuItemPressEvent>) => {
      const { itemText, selectedText, selectionStart, selectionEnd } =
        e.nativeEvent;
      const callback = contextMenuCallbacksRef.current.get(itemText);
      callback?.({
        text: selectedText,
        selection: { start: selectionStart, end: selectionEnd },
      });
    },
    []
  );

  const handleLinkPress = useCallback(
    (e: NativeSyntheticEvent<LinkPressEvent>) => {
      const { url } = e.nativeEvent;
      onLinkPress?.({ url });
    },
    [onLinkPress]
  );

  const handleLinkLongPress = useCallback(
    (e: NativeSyntheticEvent<LinkLongPressEvent>) => {
      const { url } = e.nativeEvent;
      onLinkLongPress?.({ url });
    },
    [onLinkLongPress]
  );

  const handleTaskListItemPress = useCallback(
    (e: NativeSyntheticEvent<TaskListItemPressEvent>) => {
      const { index, checked, text } = e.nativeEvent;
      onTaskListItemPress?.({ index, checked, text });
    },
    [onTaskListItemPress]
  );

  const tableMode = streamingConfig?.tableMode ?? 'progressive';
  const normalizedStreamingConfig = useMemo(() => ({ tableMode }), [tableMode]);
  const normalizedSelectionMenuConfig = useMemo(() => {
    // The boolean acceptance is confined to this wrapper boundary via a single
    // `as unknown` cast; the public type only exposes the object shape.
    const config = selectionMenuConfig as
      | {
          copy?: unknown;
          copyAsMarkdown?: unknown;
          copyImageUrl?: unknown;
        }
      | undefined;

    const copy = normalizeItem(config?.copy, 'copy', true, DEFAULT_COPY_LABEL);
    const copyAsMarkdown = normalizeItem(
      config?.copyAsMarkdown,
      'copyAsMarkdown',
      true,
      DEFAULT_COPY_AS_MARKDOWN_LABEL
    );
    const copyImageUrl = normalizeItem(
      config?.copyImageUrl,
      'copyImageUrl',
      true,
      DEFAULT_COPY_IMAGE_URL_LABEL
    );

    const pluralLabels = (
      config?.copyImageUrl as
        | { pluralLabels?: SelectionMenuPluralLabels }
        | undefined
    )?.pluralLabels;

    return {
      copyAsMarkdown: copyAsMarkdown.enabled,
      copyImageUrl: copyImageUrl.enabled,
      copyLabel: copy.label,
      copyAsMarkdownLabel: copyAsMarkdown.label,
      copyImageUrlLabel: copyImageUrl.label,
      copyImageUrlsLabel: pluralLabels?.other ?? DEFAULT_COPY_IMAGE_URLS_LABEL,
      copyImageUrlPluralTemplates: buildPluralTemplates(
        pluralLabels,
        copyImageUrl.label
      ),
    };
  }, [selectionMenuConfig]);

  const sharedProps = {
    markdown,
    markdownStyle: normalizedStyle,
    onLinkPress: handleLinkPress,
    onLinkLongPress: handleLinkLongPress,
    onTaskListItemPress: handleTaskListItemPress,
    enableLinkPreview: onLinkLongPress == null && (enableLinkPreview ?? true),
    selectable,
    md4cFlags: normalizedMd4cFlags,
    allowFontScaling,
    maxFontSizeMultiplier,
    allowTrailingMargin,
    streamingAnimation,
    streamingConfig: normalizedStreamingConfig,
    spoilerOverlay,
    style: containerStyle,
    contextMenuItems: nativeContextMenuItems,
    selectionMenuConfig: normalizedSelectionMenuConfig,
    onContextMenuItemPress: handleContextMenuItemPress,
    selectionColor,
    selectionHandleColor,
    textBreakStrategy,
    lineBreakStrategyIOS,
    writingDirection,
    ...rest,
  };

  if (flavor === 'github') {
    return <EnrichedMarkdownNativeComponent {...sharedProps} />;
  }

  return <EnrichedMarkdownTextNativeComponent {...sharedProps} />;
};

export default EnrichedMarkdownText;
