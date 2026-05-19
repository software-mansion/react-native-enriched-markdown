import { useRef, useState, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  FlatList,
  ScrollView,
  Pressable,
  TouchableOpacity,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Alert,
  type ListRenderItemInfo,
} from 'react-native';
import { useHeaderHeight } from '@react-navigation/elements';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  EnrichedMarkdownTextInput,
  EnrichedMarkdownText,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
  type CaretRect,
} from 'react-native-enriched-markdown';
import { FormattingToolbar } from '../../components/FormattingToolbar';

interface Message {
  id: number;
  markdown: string;
  isOwn: boolean;
  time: string;
}

interface MentionItem {
  name: string;
  url: string;
}

const USER_MENTIONS: MentionItem[] = [
  { name: 'John Doe', url: 'user://u_1' },
  { name: 'Jane Smith', url: 'user://u_2' },
  { name: 'Alice Johnson', url: 'user://u_3' },
  { name: 'Bob Brown', url: 'user://u_4' },
];

const CHANNEL_MENTIONS: MentionItem[] = [
  { name: 'General', url: 'channel://c_1' },
  { name: 'Random', url: 'channel://c_2' },
  { name: 'Engineering', url: 'channel://c_3' },
  { name: 'Private channel', url: 'channel://c_4' },
];

const INITIAL_MESSAGES: Message[] = [
  {
    id: 1,
    markdown:
      'Hey [@Jane Smith](user://u_2), try the rich text editor below 👇',
    isOwn: false,
    time: '10:51',
  },
  {
    id: 2,
    markdown:
      'Sure! It supports **bold**, *italic*, ~~strikethrough~~ and _underline_.',
    isOwn: true,
    time: '10:52',
  },
  {
    id: 3,
    markdown:
      'You can also add [links](https://github.com), mention [@Alice Johnson](user://u_3), and post to [#Engineering](channel://c_3).',
    isOwn: true,
    time: '10:52',
  },
  {
    id: 4,
    markdown:
      'You can hide text with ||spoiler tags|| too — great for surprises!',
    isOwn: false,
    time: '10:53',
  },
  {
    id: 5,
    markdown:
      'Type @ or # to open mention suggestions. The toolbar still lets you toggle formatting at the cursor.',
    isOwn: true,
    time: '10:53',
  },
];

const MARKDOWN_STYLE = {
  link: { color: '#2563EB', underline: true },
  linkVariants: {
    '^user:': {
      color: '#1264A3',
      backgroundColor: '#E8F5FB',
      underline: false,
    },
    '^channel:': {
      color: '#065F46',
      backgroundColor: '#D1FAE5',
      underline: false,
    },
  },
};

let nextId = 6;

function MentionSuggestionPopup({
  indicator,
  data,
  top,
  onItemPress,
}: {
  indicator: string | null;
  data: MentionItem[];
  top: number;
  onItemPress: (item: MentionItem) => void;
}) {
  if (indicator == null || data.length === 0) return null;

  const isUserMention = indicator === '@';
  const renderItem = ({ item }: ListRenderItemInfo<MentionItem>) => (
    <Pressable
      style={({ pressed }) => [
        styles.mentionItem,
        pressed && styles.mentionItemPressed,
      ]}
      onPress={() => onItemPress(item)}
    >
      <View style={styles.mentionAvatar}>
        <Text style={styles.mentionAvatarText}>
          {isUserMention ? '@' : '#'}
        </Text>
      </View>
      <Text style={styles.mentionName}>{item.name}</Text>
    </Pressable>
  );

  return (
    <View style={[styles.mentionPopup, { top }]}>
      <FlatList
        keyboardShouldPersistTaps="handled"
        overScrollMode="never"
        data={data}
        keyExtractor={(item) => item.url}
        renderItem={renderItem}
        style={styles.mentionList}
      />
    </View>
  );
}

export default function InputScreen() {
  const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);
  const scrollRef = useRef<React.ComponentRef<typeof ScrollView>>(null);
  const [state, setState] = useState<StyleState | null>(null);
  const [messages, setMessages] = useState<Message[]>(INITIAL_MESSAGES);
  const [hasSelection, setHasSelection] = useState(false);
  const [activeMention, setActiveMention] = useState<{
    indicator: string;
    text: string;
  } | null>(null);
  const [caretRect, setCaretRect] = useState<CaretRect | null>(null);
  const [inputRowY, setInputRowY] = useState(0);
  const navHeaderHeight = useHeaderHeight();
  const { bottom: bottomInset } = useSafeAreaInsets();

  const mentionSuggestions = useMemo(() => {
    if (activeMention == null) return [];

    const source =
      activeMention.indicator === '@' ? USER_MENTIONS : CHANNEL_MENTIONS;
    const query = activeMention.text.toLowerCase();

    return source.filter((item) => item.name.toLowerCase().startsWith(query));
  }, [activeMention]);

  const sendMessage = useCallback(async () => {
    const md = await inputRef.current?.getMarkdown();
    if (!md || md.trim().length === 0) return;

    const now = new Date();
    const time = `${now.getHours()}:${String(now.getMinutes()).padStart(2, '0')}`;

    setMessages((prev) => [
      ...prev,
      { id: nextId++, markdown: md.trim(), isOwn: true, time },
    ]);

    inputRef.current?.setValue('');
    setActiveMention(null);
    setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
  }, []);

  const handleMentionSelected = useCallback((item: MentionItem) => {
    const indicator = item.url.startsWith('user://') ? '@' : '#';
    inputRef.current?.insertMention(`${indicator}${item.name}`, item.url);
    setActiveMention(null);
  }, []);

  const bubbleContextMenuItems = useMemo(
    () => [
      {
        text: 'Summarize with AI',
        icon: Platform.OS === 'ios' ? 'sparkles' : undefined,
        onPress: ({ text }: { text: string }) => {
          Alert.alert('✦ Summarize with AI', `"${text}"`, [
            { text: 'Dismiss', style: 'cancel' },
          ]);
        },
      },
      {
        text: 'Reply',
        icon:
          Platform.OS === 'ios' ? 'arrowshape.turn.up.left.fill' : undefined,
        onPress: ({ text }: { text: string }) => {
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
      <View style={styles.header}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>JD</Text>
        </View>
        <View>
          <Text style={styles.headerName}>John Doe</Text>
          <Text style={styles.headerStatus}>online</Text>
        </View>
      </View>

      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={navHeaderHeight / 1.25}
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
            <View
              key={msg.id}
              style={[
                styles.messageRow,
                msg.isOwn ? styles.messageRowOwn : styles.messageRowOther,
              ]}
            >
              <View
                style={[
                  styles.bubble,
                  msg.isOwn ? styles.bubbleOwn : styles.bubbleOther,
                ]}
              >
                <EnrichedMarkdownText
                  containerStyle={
                    msg.isOwn ? styles.bubbleTextOwn : styles.bubbleTextOther
                  }
                  markdownStyle={MARKDOWN_STYLE}
                  markdown={msg.markdown}
                  md4cFlags={{ underline: true }}
                  contextMenuItems={bubbleContextMenuItems}
                />
                <Text
                  style={[
                    styles.bubbleTime,
                    msg.isOwn ? styles.bubbleTimeOwn : styles.bubbleTimeOther,
                  ]}
                >
                  {msg.time}
                </Text>
              </View>
            </View>
          ))}
        </ScrollView>
        <FormattingToolbar
          state={state}
          inputRef={inputRef}
          hasSelection={hasSelection}
          mentionIndicators={['@', '#']}
        />
        <View
          style={[styles.inputRow, { paddingBottom: 12 + bottomInset }]}
          onLayout={(e) => setInputRowY(e.nativeEvent.layout.y)}
        >
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder="Message..."
            placeholderTextColor="#9CA3AF"
            style={styles.input}
            markdownStyle={MARKDOWN_STYLE}
            mentionIndicators={['@', '#']}
            onChangeState={setState}
            onCaretRectChange={setCaretRect}
            onChangeSelection={(sel) => setHasSelection(sel.start !== sel.end)}
            onStartMention={({ indicator }) => {
              setActiveMention({ indicator, text: '' });
            }}
            onChangeMention={({ indicator, text }) => {
              setActiveMention({ indicator, text });
            }}
            onEndMention={() => {
              setActiveMention(null);
            }}
            contextMenuItems={inputContextMenuItems}
          />
          <TouchableOpacity style={styles.sendButton} onPress={sendMessage}>
            <Text style={styles.sendIcon}>▶</Text>
          </TouchableOpacity>
        </View>
        <MentionSuggestionPopup
          indicator={activeMention?.indicator ?? null}
          data={mentionSuggestions}
          top={Math.max(0, inputRowY + (caretRect?.y ?? 0) - 172)}
          onItemPress={handleMentionSelected}
        />
      </KeyboardAvoidingView>
    </View>
  );
}

const TEAL = '#4A9EBF';
const OWN_BUBBLE = '#DCFCE7';
const OTHER_BUBBLE = '#FFFFFF';

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
  avatar: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: '#2980B9',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 14,
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
  messageList: {
    flex: 1,
  },
  messageListContent: {
    paddingHorizontal: 12,
    paddingVertical: 12,
    gap: 6,
  },
  messageRow: {
    flexDirection: 'row',
  },
  messageRowOwn: {
    justifyContent: 'flex-end',
  },
  messageRowOther: {
    justifyContent: 'flex-start',
  },
  bubble: {
    maxWidth: '78%',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingTop: 8,
    paddingBottom: 6,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 2,
    shadowOffset: { width: 0, height: 1 },
    elevation: 1,
  },
  bubbleOwn: {
    backgroundColor: OWN_BUBBLE,
    borderBottomRightRadius: 4,
  },
  bubbleOther: {
    backgroundColor: OTHER_BUBBLE,
    borderBottomLeftRadius: 4,
  },

  bubbleTextOwn: {
    color: '#111827',
  },
  bubbleTextOther: {
    color: '#111827',
  },
  bubbleTime: {
    fontSize: 11,
    marginTop: 4,
    alignSelf: 'flex-end',
  },
  bubbleTimeOwn: {
    color: '#6B9E6B',
  },
  bubbleTimeOther: {
    color: '#9CA3AF',
  },
  mentionPopup: {
    position: 'absolute',
    left: 12,
    right: 12,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#CBD5E1',
    backgroundColor: '#FFFFFF',
    shadowColor: '#000',
    shadowOpacity: 0.08,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: -2 },
    elevation: 4,
    zIndex: 10,
  },
  mentionList: {
    maxHeight: 164,
  },
  mentionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  mentionItemPressed: {
    backgroundColor: '#EEF2FF',
  },
  mentionAvatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#E5E7EB',
    justifyContent: 'center',
    alignItems: 'center',
  },
  mentionAvatarText: {
    color: '#4B5563',
    fontWeight: '700',
    fontSize: 16,
  },
  mentionName: {
    color: '#111827',
    fontSize: 15,
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
