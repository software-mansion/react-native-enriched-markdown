import { useState, useMemo } from 'react';
import {
  StyleSheet,
  ScrollView,
  Alert,
  Linking,
  Platform,
  View,
  Text,
} from 'react-native';
import {
  EnrichedMarkdownText,
  type LinkPressEvent,
} from 'react-native-enriched-markdown';
import { SafeAreaView } from 'react-native-safe-area-context';
import { sampleMarkdown } from './sampleMarkdown';
import { customMarkdownStyle } from './markdownStyles';
import InputScreen from './InputScreen';
import StreamingMarkdownSimulator from './StreamingMarkdownSimulator';

type Screen = 'text' | 'input' | 'stream';

export default function App() {
  const [screen, setScreen] = useState<Screen>('input');
  const markdownStyle = useMemo(() => customMarkdownStyle, []);

  const contextMenuItems = useMemo(
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
        text: 'Translate',
        icon: Platform.OS === 'ios' ? 'globe' : undefined,
        onPress: ({ text }: { text: string }) => {
          Alert.alert('Translate', `"${text}"`, [
            { text: 'Dismiss', style: 'cancel' },
          ]);
        },
      },
    ],
    []
  );

  const handleLinkPress = (event: LinkPressEvent) => {
    const { url } = event;
    Alert.alert('Link Pressed!', `You tapped on: ${url}`, [
      {
        text: 'Open in Browser',
        onPress: () => {
          Linking.openURL(url);
        },
      },
      {
        text: 'Cancel',
        style: 'cancel',
      },
    ]);
  };

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.tabs}>
        <Text
          style={[styles.tab, screen === 'input' && styles.tabActive]}
          onPress={() => setScreen('input')}
        >
          Input
        </Text>
        <Text
          style={[styles.tab, screen === 'text' && styles.tabActive]}
          onPress={() => setScreen('text')}
        >
          Text
        </Text>
        <Text
          style={[styles.tab, screen === 'stream' && styles.tabActive]}
          onPress={() => setScreen('stream')}
        >
          Stream
        </Text>
      </View>

      {screen === 'input' ? (
        <InputScreen />
      ) : screen === 'stream' ? (
        <StreamingMarkdownSimulator />
      ) : (
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.content}
        >
          <EnrichedMarkdownText
            flavor="github"
            markdown={sampleMarkdown}
            onLinkPress={handleLinkPress}
            markdownStyle={markdownStyle}
            contextMenuItems={contextMenuItems}
            selectionColor={Platform.OS === 'ios' ? '#5A52FA' : '#DCDDFE'}
            selectionHandleColor="#5A52FA"
            selectionMenuConfig={{
              copyAsMarkdown: true,
              copyImageUrl: true,
            }}
          />
        </ScrollView>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  tabs: {
    flexDirection: 'row',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D1D5DB',
  },
  tab: {
    flex: 1,
    textAlign: 'center',
    paddingVertical: 12,
    fontSize: 15,
    fontWeight: '500',
    color: '#6B7280',
  },
  tabActive: {
    color: '#2563EB',
    borderBottomWidth: 2,
    borderBottomColor: '#2563EB',
  },
  scrollView: {
    paddingHorizontal: 16,
  },
  content: {
    paddingVertical: 16,
  },
});
