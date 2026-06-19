import { View, Text, StyleSheet } from 'react-native';

const UNREAD_RED = '#F23F42';

export function UnreadDivider({ count }: { count: number }) {
  return (
    <View style={styles.row}>
      <View style={styles.line} />
      <Text style={styles.label}>{count} new messages</Text>
      <View style={styles.line} />
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginVertical: 4,
  },
  line: {
    flex: 1,
    height: StyleSheet.hairlineWidth,
    backgroundColor: UNREAD_RED,
  },
  label: {
    fontSize: 11,
    fontWeight: '600',
    color: UNREAD_RED,
  },
});
