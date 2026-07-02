import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const ORDERED_LIST_WITH_CODE_BLOCKS_LOOSE = `1. Install via npm:
   \`\`\`
   npm install
   \`\`\`

2. Authenticate with GitHub:
   \`\`\`
   gh auth login
   \`\`\`

   This opens your browser for OAuth. Once authorized, tokens are stored locally at \`~/.config/gh/tokens.json\`.

3. Verify the connection:
   \`\`\`
   gh repo list
   \`\`\`

That's it - you're ready to query your portfolios.`;

const ORDERED_LIST_WITH_CODE_BLOCKS_TIGHT = `1. Install via npm:
   \`\`\`
   npm install
   \`\`\`
2. Authenticate with GitHub:
   \`\`\`
   gh auth login
   \`\`\`
   This opens your browser for OAuth. Once authorized, tokens are stored locally at \`~/.config/gh/tokens.json\`.
3. Verify the connection:
   \`\`\`
   gh repo list
   \`\`\`
That's it - you're ready to query your portfolios.`;

const SIMPLE_ORDERED_LIST = `1. First item
2. Second item
3. Third item`;

const STANDALONE_CODE_BLOCK = `\`\`\`bash
gh auth login
gh repo list
\`\`\``;

const EXAMPLES = [
  {
    key: 'ordered-list-with-code-loose',
    title: 'Ordered list with fenced code blocks — LOOSE (issue #243)',
    markdown: ORDERED_LIST_WITH_CODE_BLOCKS_LOOSE,
  },
  {
    key: 'ordered-list-with-code-tight',
    title: 'Ordered list with fenced code blocks — TIGHT',
    markdown: ORDERED_LIST_WITH_CODE_BLOCKS_TIGHT,
  },
  {
    key: 'simple-ordered-list',
    title: 'Simple ordered list',
    markdown: SIMPLE_ORDERED_LIST,
  },
  {
    key: 'standalone-code-block',
    title: 'Standalone fenced code block',
    markdown: STANDALONE_CODE_BLOCK,
  },
];

export default function ListsScreen() {
  return (
    <ScrollView contentContainerStyle={styles.content} testID="lists-screen">
      {EXAMPLES.map((example) => (
        <View key={example.key} style={styles.card}>
          <Text style={styles.cardTitle}>{example.title}</Text>
          <EnrichedMarkdownText markdown={example.markdown} />
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: {
    padding: 16,
    paddingBottom: 32,
  },
  card: {
    backgroundColor: 'white',
    borderRadius: 10,
    padding: 16,
    marginBottom: 16,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#d0d0d0',
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
});
