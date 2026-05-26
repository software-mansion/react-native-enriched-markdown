import React, { useMemo, useState } from 'react';
import {
  ScrollView,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  StyleSheet,
} from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { EnrichedMarkdownTextProps } from 'react-native-enriched-markdown';
import { ControlRow, initControlState, setPath } from '../common/StoryControls';
import type { StoryControl } from '../common/StoryControls';
import ExpandIcon from '../../../../src/assets/icons/expand_all_24dp.svg';
import CollapseIcon from '../../../../src/assets/icons/collapse_all_24dp.svg';

type EnrichedMarkdownTextStoryProps = {
  title: string;
  description: string;
  markdown: string;
  controls?: StoryControl[];
};

export function EnrichedMarkdownTextStory({
  title,
  description,
  markdown: initialMarkdown,
  controls = [],
}: EnrichedMarkdownTextStoryProps) {
  const [markdown, setMarkdown] = useState(initialMarkdown);
  const [controlState, setControlState] = useState<Record<string, unknown>>(
    () => initControlState(controls)
  );
  const [styleJson, setStyleJson] = useState('');
  const [styleExpanded, setStyleExpanded] = useState(false);

  const assembledProps = useMemo<Partial<EnrichedMarkdownTextProps>>(() => {
    let props: Record<string, unknown> = {};
    for (const [path, value] of Object.entries(controlState)) {
      props = setPath(props, path, value);
    }
    if (styleJson.trim()) {
      try {
        props.markdownStyle = JSON.parse(styleJson);
      } catch {
        // invalid JSON — keep previous
      }
    }
    return props as Partial<EnrichedMarkdownTextProps>;
  }, [controlState, styleJson]);

  console.log(assembledProps);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>

      <View style={styles.innerContainer}>
        <Text style={styles.sectionLabel}>Markdown</Text>
        <TextInput
          style={styles.markdownInput}
          value={markdown}
          onChangeText={setMarkdown}
          multiline
          autoCorrect={false}
          autoCapitalize="none"
        />
      </View>

      {controls.length > 0 && (
        <View style={styles.innerContainer}>
          <Text style={styles.sectionLabel}>Settings</Text>
          {controls.map((ctrl) => (
            <ControlRow
              key={ctrl.prop}
              control={ctrl}
              value={controlState[ctrl.prop]}
              onChange={(v) =>
                setControlState((prev) => ({ ...prev, [ctrl.prop]: v }))
              }
            />
          ))}
        </View>
      )}

      <View style={styles.innerContainer}>
        <TouchableOpacity
          style={styles.collapseHeader}
          onPress={() => setStyleExpanded((v) => !v)}
          activeOpacity={0.7}
        >
          <Text style={styles.sectionLabel}>Global Style</Text>
          {styleExpanded ? (
            <CollapseIcon width={16} height={16} color="#555" />
          ) : (
            <ExpandIcon width={16} height={16} color="#555" />
          )}
        </TouchableOpacity>
        {styleExpanded && (
          <TextInput
            style={[styles.markdownInput, styles.codeInput]}
            value={styleJson}
            onChangeText={setStyleJson}
            multiline
            autoCorrect={false}
            autoCapitalize="none"
            placeholder={'{\n  "body": { "fontSize": 16 }\n}'}
            placeholderTextColor="#aaa"
          />
        )}
      </View>

      <View style={styles.innerContainer}>
        <Text style={styles.sectionLabel}>Output</Text>
        <View style={styles.output}>
          <EnrichedMarkdownText markdown={markdown} {...assembledProps} />
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 16,
    gap: 8,
  },
  innerContainer: {
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
  sectionLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
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
  codeInput: {
    minHeight: 100,
  },
  output: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 10,
    minHeight: 48,
  },
  collapseHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginTop: 8,
  },
});
