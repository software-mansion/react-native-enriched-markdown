import React, { useState } from 'react';
import {
  Button,
  ScrollView,
  Text,
  TextInput,
  View,
  StyleSheet,
} from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { EnrichedMarkdownTextProps } from 'react-native-enriched-markdown';

type Props = {
  title: string;
  description: string;
  // 'style' is the short Controls-panel key for markdownStyle
  style?: EnrichedMarkdownTextProps['markdownStyle'];
} & EnrichedMarkdownTextProps;

export function EnrichedMarkdownTextStory({
  title,
  description,
  markdown: initialMarkdown,
  style,
  ...props
}: Props) {
  const [markdown, setMarkdown] = useState(initialMarkdown);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>

      <View style={styles.block}>
        <Text style={styles.label}>Markdown</Text>
        <TextInput
          style={styles.markdownInput}
          value={markdown}
          onChangeText={setMarkdown}
          multiline
          autoCorrect={false}
          autoCapitalize="none"
        />
      </View>

      <View style={styles.block}>
        <Text style={styles.label}>Output</Text>
        <View style={styles.output}>
          <EnrichedMarkdownText
            markdown={markdown}
            markdownStyle={style}
            {...props}
          />
        </View>
      </View>
    </ScrollView>
  );
}

export function SpoilerStory({
  overlay,
  onReloadSpoiler,
  ...props
}: EnrichedMarkdownTextProps & Record<string, any>) {
  const [key, setKey] = React.useState(0);
  return (
    <View>
      <EnrichedMarkdownTextStory
        key={key}
        {...props}
        spoilerOverlay={overlay}
      />
      <View style={styles.reloadButton}>
        <Button
          onPress={() => {
            setKey((k) => k + 1);
            onReloadSpoiler?.();
          }}
          title="Reload Spoiler"
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 16,
    gap: 8,
  },
  block: {
    paddingVertical: 8,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
  },
  description: {
    fontSize: 14,
    color: '#555',
    marginBottom: 4,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 6,
  },
  markdownInput: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 10,
    fontFamily: 'monospace',
    fontSize: 13,
    minHeight: 80,
    color: '#222',
  },
  output: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 10,
    minHeight: 48,
  },
  reloadButton: {
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
});
