import React, { useEffect, useRef } from 'react';
import {
  Alert,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

const SAMPLE_MARKDOWN =
  '**Bold**, *italic*, and a [link](https://reactnative.dev) walk into a bar. ~~Strikethrough~~ follows them in.';

export default storyMeta('Methods', 'CopyToClipboard');

function CopyToClipboardDemo() {
  const sourceRef = useRef<EnrichedMarkdownTextInputInstance>(null);
  const targetRef = useRef<EnrichedMarkdownTextInputInstance>(null);

  useEffect(() => {
    sourceRef.current?.setValue(SAMPLE_MARKDOWN);
  }, []);

  return (
    <ScrollView
      contentContainerStyle={styles.container}
      keyboardShouldPersistTaps="handled"
    >
      <Text style={styles.title}>copyToClipboard()</Text>
      <Text style={styles.description}>
        Ref method that copies the full input contents to the system clipboard
        without touching the current selection. On iOS/macOS a private Markdown
        pasteboard type is also written, so pasting back into an
        EnrichedMarkdownTextInput restores formatting. On Android and for
        external paste targets, only plain text is available.
      </Text>

      <View style={styles.block}>
        <Text style={styles.label}>Source input</Text>
        <View style={styles.editorContainer}>
          <EnrichedMarkdownTextInput
            ref={sourceRef}
            placeholder="Type markdown here..."
            placeholderTextColor="#9CA3AF"
            style={styles.input}
          />
        </View>
        <TouchableOpacity
          style={styles.copyButton}
          onPress={() => {
            sourceRef.current?.copyToClipboard();
            Alert.alert('Copied', 'Source input copied to clipboard.', [
              { text: 'OK' },
            ]);
          }}
        >
          <Text style={styles.copyButtonText}>Copy to clipboard</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.block}>
        <Text style={styles.label}>Paste target</Text>
        <Text style={styles.hint}>
          Focus this input and paste to verify the round-trip.
        </Text>
        <View style={styles.editorContainer}>
          <EnrichedMarkdownTextInput
            ref={targetRef}
            placeholder="Paste here..."
            placeholderTextColor="#9CA3AF"
            style={styles.input}
          />
        </View>
      </View>
    </ScrollView>
  );
}

export const Default: InputStory = {
  render: () => <CopyToClipboardDemo />,
};

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
    marginBottom: 4,
  },
  block: {
    paddingVertical: 8,
    gap: 8,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  hint: {
    fontSize: 13,
    color: '#6B7280',
  },
  editorContainer: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    overflow: 'hidden',
    backgroundColor: '#fff',
  },
  input: {
    minHeight: 120,
    maxHeight: 200,
    fontSize: 15,
    color: '#111827',
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  copyButton: {
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: '#BEEBD0',
    alignItems: 'center',
  },
  copyButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#001A72',
  },
});
