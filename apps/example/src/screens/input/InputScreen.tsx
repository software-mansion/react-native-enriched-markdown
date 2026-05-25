import { useRef, useState, useCallback, useMemo } from 'react';
import {
  View,
  ScrollView,
  KeyboardAvoidingView,
  Keyboard,
  Platform,
  Alert,
  StyleSheet,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MessageBubble } from './MessageBubble';
import { UnreadDivider } from './UnreadDivider';
import { ChannelHeader } from './ChannelHeader';
import { ChannelPickerModal } from './ChannelPickerModal';
import { MessageComposer, type MessageComposerHandle } from './MessageComposer';
import type { RootStackScreenProps } from '../../navigation/types';
import type { BubbleContextMenuItem, MessageItem } from './types';
import { MY_NICK, CHANNEL_DATA, buildMessages } from './channelData';

type Props = RootStackScreenProps<'Input'>;

export default function InputScreen({ navigation, route }: Props) {
  const channel = route.params.channel;
  const scrollRef = useRef<React.ComponentRef<typeof ScrollView>>(null);
  const composerRef = useRef<MessageComposerHandle>(null);
  const nextIdRef = useRef((CHANNEL_DATA[channel]?.messages.length ?? 0) + 2);
  const [messages, setMessages] = useState<MessageItem[]>(() =>
    buildMessages(channel)
  );
  const [channelPickerVisible, setChannelPickerVisible] = useState(false);
  const { top: topInset } = useSafeAreaInsets();

  const handleSend = useCallback((markdown: string) => {
    const now = new Date();
    const time = `${now.getHours()}:${String(now.getMinutes()).padStart(2, '0')}`;
    setMessages((prev) => [
      ...prev,
      {
        id: nextIdRef.current++,
        kind: 'message',
        nick: MY_NICK,
        message: markdown,
        time,
      },
    ]);
    setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
  }, []);

  const handleBubbleLinkPress = useCallback(
    ({ url }: { url: string }) => {
      if (url.startsWith('channel://')) {
        navigation.push('Input', { channel: url.slice('channel://'.length) });
      }
    },
    [navigation]
  );

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
          composerRef.current?.setValue(`> ${text}\n\n`);
        },
      },
    ],
    []
  );

  return (
    <View style={styles.container} testID="input-screen">
      <ChannelHeader
        channel={channel}
        topInset={topInset}
        canGoBack={navigation.canGoBack()}
        onBack={() => navigation.goBack()}
        onPress={() => setChannelPickerVisible(true)}
      />
      <ChannelPickerModal
        visible={channelPickerVisible}
        channel={channel}
        onClose={() => setChannelPickerVisible(false)}
        onSelect={(name) => {
          setChannelPickerVisible(false);
          navigation.replace('Input', { channel: name });
        }}
      />
      <KeyboardAvoidingView style={styles.body} behavior="position" enabled>
        <ScrollView
          ref={scrollRef}
          style={styles.messageList}
          contentContainerStyle={styles.messageListContent}
          keyboardShouldPersistTaps="handled"
          onScrollBeginDrag={() => Keyboard.dismiss()}
        >
          {messages.map((item) =>
            item.kind === 'divider' ? (
              <UnreadDivider key={item.id} count={item.count} />
            ) : (
              <MessageBubble
                key={item.id}
                nick={item.nick}
                time={item.time}
                message={item.message}
                isMe={item.nick === MY_NICK}
                contextMenuItems={bubbleContextMenuItems}
                onLinkPress={handleBubbleLinkPress}
              />
            )
          )}
        </ScrollView>
        <MessageComposer
          ref={composerRef}
          channel={channel}
          onSend={handleSend}
        />
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#E8F4F8',
  },
  body: {
    flex: 1,
    flexDirection: 'column',
    justifyContent: 'flex-end',
  },
  messageList: {
    flex: 1,
  },
  messageListContent: {
    paddingTop: 16,
    paddingHorizontal: 12,
    paddingBottom: 12,
    gap: 10,
  },
});
