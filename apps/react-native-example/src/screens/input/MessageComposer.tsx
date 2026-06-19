import {
  useRef,
  useState,
  useCallback,
  useMemo,
  useEffect,
  forwardRef,
  useImperativeHandle,
} from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Keyboard,
  Platform,
  Alert,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
  type CaretRect,
} from 'react-native-enriched-markdown';
import { FormattingToolbar } from '../../components/FormattingToolbar';
import { MentionSuggestionPopup } from './MentionSuggestionPopup';
import { USER_MENTIONS, CHANNEL_MENTIONS } from './channelData';
import { MARKDOWN_STYLE } from './markdownStyle';
import type { MentionItem } from './types';

const MAIN_COLOR = '#BEEBD0';
const MAIN_TEXT = '#001A72';

export type MessageComposerHandle = {
  setValue: (text: string) => void;
  focus: () => void;
};

type Props = {
  channel: string;
  onSend: (markdown: string) => void;
};

export const MessageComposer = forwardRef<MessageComposerHandle, Props>(
  function MessageComposer({ channel, onSend }, ref) {
    const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);
    const [state, setState] = useState<StyleState | null>(null);
    const [hasSelection, setHasSelection] = useState(false);
    const [activeMention, setActiveMention] = useState<{
      indicator: string;
      text: string;
    } | null>(null);
    const [caretRect, setCaretRect] = useState<CaretRect | null>(null);
    const [inputRowY, setInputRowY] = useState(0);
    const [keyboardVisible, setKeyboardVisible] = useState(false);
    const { bottom: bottomInset } = useSafeAreaInsets();

    useEffect(() => {
      const show = Keyboard.addListener('keyboardWillShow', () =>
        setKeyboardVisible(true)
      );
      const hide = Keyboard.addListener('keyboardWillHide', () =>
        setKeyboardVisible(false)
      );
      return () => {
        show.remove();
        hide.remove();
      };
    }, []);

    const mentionSuggestions = useMemo(() => {
      if (activeMention == null) return [];
      const source =
        activeMention.indicator === '@' ? USER_MENTIONS : CHANNEL_MENTIONS;
      const query = activeMention.text.toLowerCase();
      return source.filter((item) => item.name.toLowerCase().startsWith(query));
    }, [activeMention]);

    useImperativeHandle(ref, () => ({
      setValue: (text: string) => {
        inputRef.current?.setValue(text);
        inputRef.current?.focus();
      },
      focus: () => inputRef.current?.focus(),
    }));

    const handleSend = useCallback(async () => {
      const md = await inputRef.current?.getMarkdown();
      if (!md || md.trim().length === 0) return;
      onSend(md.trim());
      inputRef.current?.setValue('');
      setActiveMention(null);
    }, [onSend]);

    const handleMentionSelected = useCallback((item: MentionItem) => {
      const indicator = item.url.startsWith('user://') ? '@' : '#';
      inputRef.current?.insertMention(`${indicator}${item.name}`, item.url);
      setActiveMention(null);
    }, []);

    const contextMenuItems = useMemo(
      () => [
        {
          text: '✦ Summarize with AI',
          icon: Platform.OS === 'ios' ? 'sparkles' : undefined,
          onPress: ({
            text,
            styleState,
          }: {
            text: string;
            styleState: StyleState;
          }) => {
            const flags = [
              styleState.bold.isActive && 'bold',
              styleState.italic.isActive && 'italic',
              styleState.underline.isActive && 'underline',
              styleState.strikethrough.isActive && 'strikethrough',
              styleState.spoiler.isActive && 'spoiler',
              styleState.link.isActive && 'link',
            ]
              .filter(Boolean)
              .join(', ');
            Alert.alert(
              '✦ Summarize with AI',
              `"${text}"${flags ? `\n\nActive styles: ${flags}` : ''}`,
              [{ text: 'Dismiss', style: 'cancel' }]
            );
          },
        },
      ],
      []
    );

    const inputRowPaddingStyle = useMemo(
      () => ({ paddingBottom: keyboardVisible ? 16 : 16 + bottomInset }),
      [keyboardVisible, bottomInset]
    );

    return (
      <>
        <FormattingToolbar
          state={state}
          inputRef={inputRef}
          hasSelection={hasSelection}
          mentionIndicators={['@', '#']}
        />
        <View
          style={[styles.inputRow, inputRowPaddingStyle]}
          onLayout={(e) => setInputRowY(e.nativeEvent.layout.y)}
        >
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder={`Message #${channel}...`}
            placeholderTextColor="#9CA3AF"
            style={styles.input}
            markdownStyle={MARKDOWN_STYLE}
            mentionIndicators={['@', '#']}
            onChangeState={setState}
            onCaretRectChange={setCaretRect}
            onChangeSelection={(sel) => setHasSelection(sel.start !== sel.end)}
            onStartMention={({ indicator }) =>
              setActiveMention({ indicator, text: '' })
            }
            onChangeMention={({ indicator, text }) =>
              setActiveMention({ indicator, text })
            }
            onEndMention={() => setActiveMention(null)}
            contextMenuItems={contextMenuItems}
          />
          <TouchableOpacity style={styles.sendButton} onPress={handleSend}>
            <Text style={styles.sendIcon}>▶</Text>
          </TouchableOpacity>
        </View>
        <MentionSuggestionPopup
          indicator={activeMention?.indicator ?? null}
          data={mentionSuggestions}
          top={Math.max(0, inputRowY + (caretRect?.y ?? 0) - 172)}
          onItemPress={handleMentionSelected}
        />
      </>
    );
  }
);

const styles = StyleSheet.create({
  inputRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 8,
    paddingHorizontal: 12,
    paddingTop: 6,
    paddingBottom: 12,
    backgroundColor: '#F9FAFB',
  },
  input: {
    flex: 1,
    minHeight: 36,
    maxHeight: 120,
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 8,
    fontSize: 15,
    color: '#111827',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#D1D5DB',
  },
  sendButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: MAIN_COLOR,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sendIcon: {
    color: MAIN_TEXT,
    fontSize: 14,
    marginLeft: 2,
  },
});
