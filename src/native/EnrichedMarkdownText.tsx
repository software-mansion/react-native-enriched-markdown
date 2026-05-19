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
};
export type { LinkPressEvent, LinkLongPressEvent, TaskListItemPressEvent };

const defaultMd4cFlags: Md4cFlags = {
  underline: false,
  superscript: false,
  subscript: false,
  latexMath: true,
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
  const normalizedSelectionMenuConfig = useMemo(
    () => ({
      copyAsMarkdown: selectionMenuConfig?.copyAsMarkdown ?? true,
      copyImageUrl: selectionMenuConfig?.copyImageUrl ?? true,
    }),
    [selectionMenuConfig]
  );

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
    ...rest,
  };

  if (flavor === 'github') {
    return <EnrichedMarkdownNativeComponent {...sharedProps} />;
  }

  return <EnrichedMarkdownTextNativeComponent {...sharedProps} />;
};

export default EnrichedMarkdownText;
