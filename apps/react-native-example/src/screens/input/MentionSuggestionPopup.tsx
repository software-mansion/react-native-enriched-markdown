import {
  View,
  Text,
  FlatList,
  Pressable,
  StyleSheet,
  type ListRenderItemInfo,
} from 'react-native';
import type { MentionItem } from './types';

type Props = {
  indicator: string | null;
  data: MentionItem[];
  top: number;
  onItemPress: (item: MentionItem) => void;
};

export function MentionSuggestionPopup({
  indicator,
  data,
  top,
  onItemPress,
}: Props) {
  if (indicator == null || data.length === 0) return null;

  const isUserMention = indicator === '@';
  const renderItem = ({ item }: ListRenderItemInfo<MentionItem>) => (
    <Pressable
      style={({ pressed }) => [styles.item, pressed && styles.itemPressed]}
      onPress={() => onItemPress(item)}
    >
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>{isUserMention ? '@' : '#'}</Text>
      </View>
      <Text style={styles.name}>{item.name}</Text>
    </Pressable>
  );

  return (
    <View style={[styles.popup, { top }]}>
      <FlatList
        keyboardShouldPersistTaps="handled"
        overScrollMode="never"
        data={data}
        keyExtractor={(item) => item.url}
        renderItem={renderItem}
        style={styles.list}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  popup: {
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
  list: {
    maxHeight: 164,
  },
  item: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  itemPressed: {
    backgroundColor: '#EEF2FF',
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#E5E7EB',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    color: '#4B5563',
    fontWeight: '700',
    fontSize: 16,
  },
  name: {
    color: '#111827',
    fontSize: 15,
  },
});
