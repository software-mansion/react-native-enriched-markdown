import { useMemo, useCallback } from 'react';
import { ScrollView, StyleSheet, Platform, Alert, Linking } from 'react-native';
import {
  EnrichedMarkdownText,
  type LinkPressEvent,
  type DataDetectorPressEvent,
} from 'react-native-enriched-markdown';
import { sampleMarkdown } from '../../sampleMarkdown';
import { customMarkdownStyle } from '../../markdownStyles';

export default function TextScreen() {
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

  const handleDataDetectorPress = useCallback(
    (event: DataDetectorPressEvent) => {
      const dataStr = Object.entries(event.data)
        .map(([k, v]) => `  ${k}: ${v}`)
        .join('\n');
      Alert.alert(
        `Data Detected: ${event.type}`,
        `Text: "${event.text}"\nURL: ${event.url}${dataStr ? `\nData:\n${dataStr}` : ''}`,
        [
          {
            text: 'Open',
            onPress: () => {
              Linking.openURL(event.url).catch(() => {});
            },
          },
          { text: 'Cancel', style: 'cancel' },
        ]
      );
    },
    []
  );

  return (
    <ScrollView
      style={styles.scrollView}
      contentContainerStyle={styles.content}
      testID="text-screen"
    >
      <EnrichedMarkdownText
        flavor="github"
        markdown={sampleMarkdown}
        onLinkPress={handleLinkPress}
        onDataDetectorPress={handleDataDetectorPress}
        dataDetectorTypes={['phoneNumber', 'email', 'link', 'date', 'address']}
        markdownStyle={markdownStyle}
        contextMenuItems={contextMenuItems}
        selectionColor={Platform.OS === 'ios' ? '#5A52FA' : '#DCDDFE'}
        selectionHandleColor="#5A52FA"
        md4cFlags={{
          superscript: true,
          subscript: true,
        }}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scrollView: {
    paddingHorizontal: 16,
  },
  content: {
    paddingVertical: 16,
  },
});
