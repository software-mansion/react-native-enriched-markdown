import {
  Modal,
  Pressable,
  Text,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import { CHANNEL_MENTIONS } from './channelData';

const MAIN_TEXT = '#001A72';

type Props = {
  visible: boolean;
  channel: string;
  onClose: () => void;
  onSelect: (channel: string) => void;
};

export function ChannelPickerModal({
  visible,
  channel,
  onClose,
  onSelect,
}: Props) {
  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
    >
      <Pressable style={styles.backdrop} onPress={onClose}>
        <Pressable style={styles.sheet} onPress={() => {}}>
          <Text style={styles.title}>Switch Channel</Text>
          {CHANNEL_MENTIONS.map((ch) => {
            const name = ch.url.slice('channel://'.length);
            const isActive = name === channel;
            return (
              <TouchableOpacity
                key={ch.url}
                style={[styles.item, isActive && styles.itemActive]}
                onPress={() => onSelect(name)}
              >
                <Text style={styles.hash}>#</Text>
                <Text
                  style={[styles.itemName, isActive && styles.itemNameActive]}
                >
                  {name}
                </Text>
                {isActive && <Text style={styles.check}>✓</Text>}
              </TouchableOpacity>
            );
          })}
        </Pressable>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'flex-start',
    alignItems: 'stretch',
  },
  sheet: {
    marginTop: 100,
    marginHorizontal: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    paddingVertical: 8,
    shadowColor: '#000',
    shadowOpacity: 0.15,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 8,
  },
  title: {
    fontSize: 13,
    fontWeight: '600',
    color: '#6B7280',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E5E7EB',
  },
  item: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 14,
    gap: 10,
  },
  itemActive: {
    backgroundColor: '#F0FDF4',
  },
  hash: {
    fontSize: 16,
    fontWeight: '700',
    color: '#9CA3AF',
    width: 16,
    textAlign: 'center',
  },
  itemName: {
    flex: 1,
    fontSize: 16,
    color: '#111827',
  },
  itemNameActive: {
    color: MAIN_TEXT,
    fontWeight: '600',
  },
  check: {
    fontSize: 16,
    color: MAIN_TEXT,
    fontWeight: '700',
  },
});
