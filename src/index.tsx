export { default as EnrichedMarkdownText } from './native/EnrichedMarkdownText';
export type {
  EnrichedMarkdownTextProps,
  StreamingConfig,
  MarkdownStyle,
  Md4cFlags,
  ContextMenuItem as TextContextMenuItem,
  SelectionMenuConfig as TextSelectionMenuConfig,
} from './native/EnrichedMarkdownText';
export type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
} from './types/events';

export { EnrichedMarkdownTextInput } from './EnrichedMarkdownTextInput';
export type {
  EnrichedMarkdownTextInputProps,
  EnrichedMarkdownTextInputInstance,
  MarkdownTextInputStyle,
  StyleState,
  ContextMenuItem,
  OnLinkDetected,
  OnStartMentionEvent,
  OnChangeMentionEvent,
  OnEndMentionEvent,
  CaretRect,
} from './EnrichedMarkdownTextInput';
