import { useRef, useState, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { useHeaderHeight } from '@react-navigation/elements';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';
import { FormattingToolbar } from '../../components/FormattingToolbar';
import { MessageBubble, type BubbleContextMenuItem } from './MessageBubble';

// ─── Types ────────────────────────────────────────────────────────────────────

type ChatMessage = {
  id: number;
  nick: string;
  time: string;
  message: string;
};

// ─── Constants ────────────────────────────────────────────────────────────────

const MY_NICK = 'me';

const INITIAL_MESSAGES: ChatMessage[] = [
  {
    id: 1,
    nick: 'alice',
    time: '14:15',
    message: 'anything new today?',
  },
  {
    id: 2,
    nick: 'dave',
    time: '14:16',
    message: 'not really, pretty quiet',
  },
  {
    id: 3,
    nick: 'bob',
    time: '14:22',
    message: '### Announcement\n\n|| I love bananas ||',
  },
  {
    id: 4,
    nick: 'carol',
    time: '14:22',
    message: '@bob you truly are a silly guy 😂',
  },
  {
    id: 5,
    nick: 'dave',
    time: '14:23',
    message: 'wait what 💀',
  },
  {
    id: 6,
    nick: 'alice',
    time: '14:23',
    message: 'I stand by this',
  },
  {
    id: 7,
    nick: 'carol',
    time: '14:24',
    message: 'someone post this in #general lmao',
  },
];

const MARKDOWN_STYLE = {
  link: { color: '#2563EB', underline: true },
};

let nextId = INITIAL_MESSAGES.length + 1;

// ─── Screen ───────────────────────────────────────────────────────────────────

export default function InputScreen() {
  const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);
  const scrollRef = useRef<React.ComponentRef<typeof ScrollView>>(null);
  const [state, setState] = useState<StyleState | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>(INITIAL_MESSAGES);
  const [hasSelection, setHasSelection] = useState(false);
  const navHeaderHeight = useHeaderHeight();
  const [chatHeaderHeight, setChatHeaderHeight] = useState(0);
  const { bottom: bottomInset } = useSafeAreaInsets();

  const sendMessage = useCallback(async () => {
    const md = await inputRef.current?.getMarkdown();
    if (!md || md.trim().length === 0) return;

    const now = new Date();
    const time = `${now.getHours()}:${String(now.getMinutes()).padStart(2, '0')}`;

    setMessages((prev) => [
      ...prev,
      { id: nextId++, nick: MY_NICK, message: md.trim(), time },
    ]);

    inputRef.current?.setValue('');
    setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
  }, []);

  const bubbleContextMenuItems = useMemo<BubbleContextMenuItem[]>(
    () => [
      {
        text: 'Summarize with AI',
        icon: Platform.OS === 'ios' ? 'sparkles' : undefined,
        onPress: ({ text }) => {
          Alert.alert('✦ Summarize with AI', `"${text}"`, [
            { text: 'Dismiss', style: 'cancel' },
          ]);
        },
      },
      {
        text: 'Reply',
        icon:
          Platform.OS === 'ios' ? 'arrowshape.turn.up.left.fill' : undefined,
        onPress: ({ text }) => {
          inputRef.current?.setValue(`> ${text}\n\n`);
          inputRef.current?.focus();
        },
      },
    ],
    []
  );

  const inputContextMenuItems = useMemo(
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

  return (
    <View style={styles.container} testID="input-screen">
      <View
        style={styles.header}
        onLayout={(e) => setChatHeaderHeight(e.nativeEvent.layout.height)}
      >
        <View style={[styles.avatar, styles.headerAvatar]}>
          <Text style={styles.avatarText}>#</Text>
        </View>
        <View>
          <Text style={styles.headerName}>#random</Text>
          <Text style={styles.headerStatus}>4 members</Text>
        </View>
      </View>

      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={navHeaderHeight + chatHeaderHeight}
      >
        <ScrollView
          ref={scrollRef}
          style={styles.messageList}
          contentContainerStyle={styles.messageListContent}
          onContentSizeChange={() =>
            scrollRef.current?.scrollToEnd({ animated: false })
          }
        >
          {messages.map((msg) => (
            <MessageBubble
              key={msg.id}
              nick={msg.nick}
              time={msg.time}
              message={msg.message}
              isMe={msg.nick === MY_NICK}
              contextMenuItems={bubbleContextMenuItems}
            />
          ))}
        </ScrollView>

        <FormattingToolbar
          state={state}
          inputRef={inputRef}
          hasSelection={hasSelection}
        />

        <View style={[styles.inputRow, { paddingBottom: 12 + bottomInset }]}>
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder="Message #random..."
            placeholderTextColor="#9CA3AF"
            style={styles.input}
            markdownStyle={MARKDOWN_STYLE}
            onChangeState={setState}
            onChangeSelection={(sel) => setHasSelection(sel.start !== sel.end)}
            contextMenuItems={inputContextMenuItems}
          />
          <TouchableOpacity style={styles.sendButton} onPress={sendMessage}>
            <Text style={styles.sendIcon}>▶</Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const TEAL = '#4A9EBF';

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#E8F4F8',
  },
  flex: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 10,
    backgroundColor: TEAL,
  },
  headerAvatar: {
    backgroundColor: 'rgba(0,0,0,0.2)',
  },
  headerName: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 16,
  },
  headerStatus: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 12,
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    flexShrink: 0,
  },
  avatarText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 12,
  },
  messageList: {
    flex: 1,
  },
  messageListContent: {
    paddingHorizontal: 12,
    paddingVertical: 12,
    gap: 10,
  },
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
    backgroundColor: TEAL,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sendIcon: {
    color: '#fff',
    fontSize: 14,
    marginLeft: 2,
  },
});
