import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';

const MAIN_COLOR = '#BEEBD0';
const MAIN_TEXT = '#001A72';

type Props = {
  channel: string;
  topInset: number;
  canGoBack: boolean;
  onBack: () => void;
  onPress: () => void;
};

export function ChannelHeader({
  channel,
  topInset,
  canGoBack,
  onBack,
  onPress,
}: Props) {
  return (
    <View style={[styles.header, { paddingTop: topInset + 4 }]}>
      {canGoBack && (
        <TouchableOpacity style={styles.backButton} onPress={onBack}>
          <Text style={styles.backIcon}>‹</Text>
        </TouchableOpacity>
      )}
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>#</Text>
      </View>
      <TouchableOpacity
        style={styles.info}
        onPress={onPress}
        activeOpacity={0.7}
      >
        <Text style={styles.name}>#{channel}</Text>
        <Text style={styles.status}>4 members · tap to switch</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 12,
    paddingBottom: 10,
    backgroundColor: MAIN_COLOR,
    zIndex: 2,
  },
  backButton: {
    width: 32,
    height: 32,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backIcon: {
    color: MAIN_TEXT,
    fontSize: 32,
    lineHeight: 36,
    fontWeight: '300',
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(0,0,0,0.2)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    color: MAIN_TEXT,
    fontWeight: '700',
    fontSize: 14,
  },
  info: {
    flex: 1,
  },
  name: {
    color: MAIN_TEXT,
    fontWeight: '700',
    fontSize: 16,
  },
  status: {
    color: 'rgba(0, 26, 114, 0.7)',
    fontSize: 12,
  },
});
