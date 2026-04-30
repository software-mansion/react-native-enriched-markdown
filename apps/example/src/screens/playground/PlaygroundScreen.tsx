import { useRef, useState, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { useHeaderHeight } from '@react-navigation/elements';
import {
  EnrichedMarkdownTextInput,
  EnrichedMarkdownText,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';
import { FormattingToolbar } from '../../components/FormattingToolbar';

const MARKDOWN_STYLE = {
  link: { color: '#2563EB', underline: true as const },
  code: { color: '#7c3aed', backgroundColor: '#f5f3ff' },
  codeBlock: {
    color: '#f3f4f6',
    backgroundColor: '#1f2937',
    borderRadius: 8,
  },
  blockquote: {
    color: '#4b5563',
    borderColor: '#d1d5db',
    borderWidth: 3,
    gapWidth: 12,
  },
  table: {
    borderColor: '#e5e7eb',
    borderRadius: 6,
    cellPaddingHorizontal: 10,
    cellPaddingVertical: 6,
  },
  taskList: {
    checkedColor: '#2563eb',
    borderColor: '#9ca3af',
    checkmarkColor: '#ffffff',
    checkedStrikethrough: true,
  },
};

export default function PlaygroundScreen() {
  const headerHeight = useHeaderHeight();
  const inputRef = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);
  const [markdown, setMarkdown] = useState('');
  const [sizeMode, setSizeMode] = useState<'base' | 'max'>('base');
  const [hasSelection, setHasSelection] = useState(false);
  const handleGetMarkdown = useCallback(async () => {
    const md = await inputRef.current?.getMarkdown();
    Alert.alert('Markdown', md ?? '(empty)', [{ text: 'OK' }]);
  }, []);

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={headerHeight}
      testID="playground-screen"
    >
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.buttonRow}>
          <TouchableOpacity
            style={styles.button}
            onPress={() => inputRef.current?.focus()}
            testID="focus-button"
          >
            <Text style={styles.buttonText}>Focus</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.button}
            onPress={() => inputRef.current?.blur()}
            testID="blur-button"
          >
            <Text style={styles.buttonText}>Blur</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.button}
            onPress={() => {
              inputRef.current?.setValue('');
              setMarkdown('');
            }}
            testID="clear-button"
          >
            <Text style={styles.buttonText}>Clear</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.button}
            onPress={() => setSizeMode((m) => (m === 'max' ? 'base' : 'max'))}
            testID="size-button"
          >
            <Text style={styles.buttonText}>
              {sizeMode === 'max' ? 'Base' : 'Max'}
            </Text>
          </TouchableOpacity>
        </View>

        <View style={styles.editorContainer} testID="editor-container">
          <EnrichedMarkdownTextInput
            ref={inputRef}
            placeholder="Type markdown here..."
            placeholderTextColor="#9CA3AF"
            style={
              sizeMode === 'max'
                ? { ...styles.input, ...styles.inputMax }
                : styles.input
            }
            markdownStyle={MARKDOWN_STYLE}
            onChangeState={setState}
            onChangeMarkdown={setMarkdown}
            onChangeSelection={(sel) => setHasSelection(sel.start !== sel.end)}
          />
          <FormattingToolbar
            state={state}
            inputRef={inputRef}
            hasSelection={hasSelection}
            testID="formatting-toolbar"
          />
        </View>

        <TouchableOpacity
          style={styles.getMarkdownButton}
          onPress={handleGetMarkdown}
          testID="get-markdown-button"
        >
          <Text style={styles.getMarkdownText}>Get Raw Markdown</Text>
        </TouchableOpacity>

        <View style={styles.divider} />

        <Text style={styles.previewLabel}>Preview</Text>
        <View style={styles.previewContainer} testID="preview-container">
          {markdown.length > 0 ? (
            <EnrichedMarkdownText
              markdown={markdown}
              markdownStyle={MARKDOWN_STYLE}
              flavor="github"
              spoilerOverlay="solid"
              md4cFlags={{ underline: true }}
              onLinkPress={({ url }) =>
                Alert.alert('Link', url, [{ text: 'OK' }])
              }
              onTaskListItemPress={({ checked, index }) =>
                Alert.alert(
                  'Task item',
                  `Item ${index} is now ${checked ? 'checked' : 'unchecked'}`,
                  [{ text: 'OK' }]
                )
              }
              testID="preview-text"
            />
          ) : (
            <Text style={styles.previewEmpty} testID="preview-empty">
              Preview will appear here
            </Text>
          )}
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F9FAFB',
  },
  scroll: {
    flex: 1,
  },
  content: {
    padding: 16,
    gap: 12,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    flex: 1,
    paddingVertical: 9,
    borderRadius: 8,
    backgroundColor: '#E5E7EB',
    alignItems: 'center',
  },
  buttonText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#374151',
  },
  editorContainer: {
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#D1D5DB',
    overflow: 'hidden',
    backgroundColor: '#FFFFFF',
  },
  input: {
    minHeight: 120,
    maxHeight: 200,
    fontSize: 15,
    color: '#111827',
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  inputMax: {
    maxHeight: 400,
  },
  getMarkdownButton: {
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: '#BEEBD0',
    alignItems: 'center',
  },
  getMarkdownText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#001A72',
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: '#E5E7EB',
    marginVertical: 4,
  },
  previewLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#9CA3AF',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  previewContainer: {
    backgroundColor: '#FFFFFF',
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#D1D5DB',
    padding: 14,
    minHeight: 80,
  },
  previewEmpty: {
    fontSize: 14,
    color: '#9CA3AF',
    fontStyle: 'italic',
  },
});
