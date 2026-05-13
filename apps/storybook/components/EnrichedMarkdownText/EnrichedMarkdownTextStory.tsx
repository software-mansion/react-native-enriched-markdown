import React, {useState} from 'react';
import {ScrollView, Text, TextInput, View, StyleSheet} from 'react-native';
import {EnrichedMarkdownText} from 'react-native-enriched-markdown';
import type {EnrichedMarkdownTextProps} from 'react-native-enriched-markdown';

interface MarkdownStoryProps extends EnrichedMarkdownTextProps {
  title: string;
  description: string;
}

export function EnrichedMarkdownTextStory({
  title,
  description,
  markdown,
  ...props
}: MarkdownStoryProps) {
  const [value, setValue] = useState(markdown);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>

      <Text style={styles.label}>Input</Text>
      <TextInput
        style={styles.input}
        value={value}
        onChangeText={setValue}
        multiline
        autoCorrect={false}
        autoCapitalize="none"
      />

      <Text style={styles.label}>Output</Text>
      <View style={styles.output}>
        <EnrichedMarkdownText markdown={value} {...props} />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 16,
    gap: 8,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
  },
  description: {
    fontSize: 14,
    color: '#555',
    marginBottom: 8,
  },
  label: {
    fontSize: 12,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  input: {
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
});
