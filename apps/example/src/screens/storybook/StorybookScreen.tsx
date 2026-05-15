import { StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import StorybookUIRoot from '../../../.rnstorybook';

export default function StorybookScreen() {
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.container, { marginTop: -insets.top }]}>
      <StorybookUIRoot />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
