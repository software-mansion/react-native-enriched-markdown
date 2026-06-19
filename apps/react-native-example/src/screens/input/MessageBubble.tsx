import { View, Text, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownText,
  type LinkPressEvent,
} from 'react-native-enriched-markdown';
import type { BubbleContextMenuItem } from './types';
import { MARKDOWN_STYLE } from './markdownStyle';

export type MessageBubbleProps = {
  nick: string;
  time: string;
  message: string;
  isMe: boolean;
  contextMenuItems: BubbleContextMenuItem[];
  onLinkPress?: (event: LinkPressEvent) => void;
};

const AVATAR_COLORS = [
  '#E57373',
  '#64B5F6',
  '#81C784',
  '#FFB74D',
  '#BA68C8',
  '#4DB6AC',
];

function nickToColor(nick: string): string {
  let h = 0;
  for (let i = 0; i < nick.length; i++) {
    h = nick.charCodeAt(i) + h * 31;
  }
  return AVATAR_COLORS[Math.abs(h) % AVATAR_COLORS.length];
}

function nickToInitials(nick: string): string {
  return nick.slice(0, 2).toUpperCase();
}

export function MessageBubble({
  nick,
  time,
  message,
  isMe,
  contextMenuItems,
  onLinkPress,
}: MessageBubbleProps) {
  return (
    <View
      style={[
        styles.messageRow,
        isMe ? styles.messageRowOwn : styles.messageRowOther,
      ]}
    >
      {!isMe && (
        <View style={[styles.avatar, { backgroundColor: nickToColor(nick) }]}>
          <Text style={styles.avatarText}>{nickToInitials(nick)}</Text>
        </View>
      )}
      <View
        style={[styles.bubble, isMe ? styles.bubbleOwn : styles.bubbleOther]}
      >
        <View style={[styles.bubbleHeader, isMe && styles.bubbleHeaderOwn]}>
          <Text style={styles.bubbleNick}>{nick}</Text>
          <Text style={styles.bubbleTime}>{time}</Text>
        </View>
        <EnrichedMarkdownText
          containerStyle={isMe ? styles.bubbleTextOwn : styles.bubbleTextOther}
          markdownStyle={MARKDOWN_STYLE}
          markdown={message}
          md4cFlags={{ underline: true }}
          contextMenuItems={contextMenuItems}
          onLinkPress={onLinkPress}
        />
      </View>
    </View>
  );
}

const OWN_BUBBLE = '#DCFCE7';
const OTHER_BUBBLE = '#FFFFFF';

const styles = StyleSheet.create({
  messageRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
  },
  messageRowOwn: {
    justifyContent: 'flex-end',
  },
  messageRowOther: {
    justifyContent: 'flex-start',
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
  bubble: {
    maxWidth: '78%',
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingTop: 6,
    paddingBottom: 8,
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
  bubbleHeader: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 6,
    marginBottom: -4,
  },
  bubbleHeaderOwn: {
    justifyContent: 'flex-end',
  },
  bubbleNick: {
    fontSize: 13,
    fontWeight: '600',
    color: '#374151',
  },
  bubbleTime: {
    fontSize: 11,
    fontWeight: '300',
    color: '#9CA3AF',
  },
  bubbleTextOwn: {
    color: '#111827',
  },
  bubbleTextOther: {
    color: '#111827',
  },
});
