import { Text, StyleSheet, TouchableOpacity } from 'react-native';

type Props = {
  label: string;
  subtext: string;
  testID: string;
  color: string;
  onPress: () => void;
};

export function HomeScreenButton({
  label,
  subtext,
  testID,
  color,
  onPress,
}: Props) {
  return (
    <TouchableOpacity
      style={[styles.button, { backgroundColor: color }]}
      onPress={onPress}
      testID={testID}
    >
      <Text style={styles.buttonText}>{label}</Text>
      <Text style={styles.buttonSubtext}>{subtext}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 10,
    marginVertical: 10,
    minWidth: 250,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
  },
  buttonSubtext: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 12,
    textAlign: 'center',
    marginTop: 2,
  },
});
