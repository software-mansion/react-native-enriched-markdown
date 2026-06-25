import React from 'react';
import { Linking, StyleSheet, View } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { MarkdownStyle } from 'react-native-enriched-markdown';

const markdown = `# Markdown accessibility test

This is a plain paragraph. VoiceOver should focus and read this paragraph as text.

This is another plain paragraph without any inline link or special formatting.

This paragraph contains a [test.de link](https://test.de) and text before and after the link.

- First plain list item
- Second list item with a [mail link](mailto:kontakt@test.de)

**Bold text** and _emphasized text_ should also be reachable.`;

const markdownStyle: MarkdownStyle = {
  paragraph: {
    color: '#1F1F21',
    fontSize: 18,
    lineHeight: 26,
    marginTop: 8,
    marginBottom: 8,
  },
  h1: {
    color: '#1F1F21',
    fontSize: 22,
    lineHeight: 28,
    marginTop: 0,
    marginBottom: 16,
  },
  list: {
    color: '#1F1F21',
    bulletColor: '#1F1F21',
    markerColor: '#1F1F21',
    fontSize: 18,
    lineHeight: 26,
    marginTop: 8,
    marginBottom: 8,
  },
  link: {
    color: '#1F1F21',
    underline: true,
  },
  strong: {
    fontWeight: 'bold',
  },
  em: {
    fontStyle: 'italic',
  },
};

export default function App() {
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        selectable
        flavor="github"
        containerStyle={styles.markdown}
        onLinkPress={({ url }) => {
          Linking.openURL(url);
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
    padding: 24,
  },
  markdown: {
    width: '100%',
  },
});
