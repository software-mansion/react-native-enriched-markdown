import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';

const md = `
\`\`\`
// server.mjs
import { createServer } from 'node:http';

const server = createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Hello World!\\n');
});

// starts a simple http server locally on port 3000
server.listen(3000, '127.0.0.1', () => {
  console.log('Listening on 127.0.0.1:3000');
});

// run with "node server.mjs"

// one more line
// one more line
// one more line
// one more line
// one more line
// one more line
// one more line
// one more line
// one more line
// one more line
// one more line
// one more line
// one more line
\`\`\`
`;

export default function App() {
  return (
    <SafeAreaProvider>
      <SafeAreaView>
        <EnrichedMarkdownText
          markdown={md}
          markdownStyle={{ codeBlock: { borderRadius: 12, padding: 19 } }}
        />
      </SafeAreaView>
    </SafeAreaProvider>
  );
}
