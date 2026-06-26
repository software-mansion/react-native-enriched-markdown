import React from 'react';
import { Linking, StyleSheet, ScrollView } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { MarkdownStyle } from 'react-native-enriched-markdown';

const markdown = `# Heading level 1

This is a plain paragraph. VoiceOver should focus and read this paragraph as text.

## Heading level 2

This is another plain paragraph without any inline link or special formatting.

This paragraph contains a [test.de link](https://test.de) and text before and after the link.

**Bold text**, _emphasized text_ and \`inline code\` should also be reachable.

> A blockquote with a single line of text.
>
> A second line in the same blockquote.

- First plain unordered item
- Second unordered item with a [mail link](mailto:kontakt@test.de)
- Third unordered item

1. First ordered item
2. Second ordered item
3. Third ordered item with **bold** inside

![Logo image used as the accessibility image example](https://placehold.co/240x80/png?text=Image)

\`\`\`js
const greeting = 'hello';
console.log(greeting);
\`\`\`

| Column A | Column B |
|----------|----------|
| Cell A1  | Cell B1  |
| Cell A2  | Cell B2  |
`;

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
    fontSize: 24,
    lineHeight: 30,
    marginTop: 0,
    marginBottom: 12,
  },
  h2: {
    color: '#1F1F21',
    fontSize: 20,
    lineHeight: 26,
    marginTop: 12,
    marginBottom: 8,
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
  code: {
    color: '#7c3aed',
    backgroundColor: '#f5f3ff',
  },
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
};

export default function App() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
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
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
  },
  content: {
    padding: 24,
  },
  markdown: {
    width: '100%',
  },
});
