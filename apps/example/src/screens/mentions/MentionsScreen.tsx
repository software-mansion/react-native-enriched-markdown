import { useCallback, useMemo, type ReactNode } from 'react';
import {
  Alert,
  Linking,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  EnrichedMarkdownText,
  type MarkdownStyle,
  type LinkPressEvent,
} from 'react-native-enriched-markdown';

const BASE_STYLE: MarkdownStyle = {
  paragraph: {
    fontSize: 16,
    color: '#1F2937',
    lineHeight: 24,
    marginBottom: 0,
  },
};

function SectionTitle({ children }: { children: string }) {
  return <Text style={styles.sectionTitle}>{children}</Text>;
}

function SectionDesc({ children }: { children: ReactNode }) {
  return <Text style={styles.sectionDesc}>{children}</Text>;
}

function ConfigBlock({ children }: { children: string }) {
  return (
    <View style={styles.configBlock}>
      <Text style={styles.configText}>{children}</Text>
    </View>
  );
}

function Card({ children }: { children: ReactNode }) {
  return <View style={styles.card}>{children}</View>;
}

export default function MentionsScreen() {
  const handleLinkPress = useCallback(({ url }: LinkPressEvent) => {
    // With regex patterns the scheme may not identify the type — parse the URL manually.
    if (url.startsWith('user://')) {
      Alert.alert('User mention', `ID: ${url.replace('user://', '')}`);
    } else if (url.startsWith('channel://')) {
      Alert.alert('Channel mention', `ID: ${url.replace('channel://', '')}`);
    } else if (url.startsWith('role://')) {
      Alert.alert('Role mention', `ID: ${url.replace('role://', '')}`);
    } else if (url.startsWith('cite://')) {
      Alert.alert('Citation', `Ref: ${url.replace('cite://', '')}`);
    } else if (url.startsWith('doi://')) {
      Alert.alert('DOI', `DOI: ${url.replace('doi://', '')}`);
    } else if (url.startsWith('tag://') || url.startsWith('team://')) {
      Alert.alert('Tag / team', url);
    } else if (url.includes('/user/')) {
      Alert.alert('Path-based user link', url);
    } else if (url.includes('/channel/')) {
      Alert.alert('Path-based channel link', url);
    } else {
      Linking.openURL(url);
    }
  }, []);

  const slackStyle = useMemo<MarkdownStyle>(
    () => ({
      ...BASE_STYLE,
      link: { color: '#1D9BD1', underline: false },
      linkVariants: {
        '^user:': { color: '#1264A3', backgroundColor: '#E8F5FB' },
        '^channel:': { color: '#1264A3', backgroundColor: '#E8F5FB' },
      },
    }),
    []
  );

  const slackMarkdown = `Hey [@alice](user://u1), can you check [#design](channel://c-design) when you have a chance? Also looping in [@bob](user://u2) and [@carol](user://u3). Check https://figma.com for the latest mockups.`;

  const discordStyle = useMemo<MarkdownStyle>(
    () => ({
      ...BASE_STYLE,
      link: { color: '#5865F2', underline: false },
      linkVariants: {
        '^user:': { color: '#5865F2', backgroundColor: '#D9DBFF' },
        '^channel:': { color: '#4F9A8A', backgroundColor: '#D4F1EB' },
        '^role:': { color: '#8B5CF6', backgroundColor: '#EDE9FE' },
      },
    }),
    []
  );

  const discordMarkdown = `[@moderators](role://r-mod) please review this. [@alice](user://u1) submitted in [#general](channel://c-general). Pinging [@admin](user://u-admin) and [@bob](user://u2) too.`;

  const citationStyle = useMemo<MarkdownStyle>(
    () => ({
      ...BASE_STYLE,
      link: { color: '#2563EB', underline: true },
      linkVariants: {
        '^cite:': {
          color: '#92400E',
          backgroundColor: '#FEF9C3',
          underline: false,
        },
        '^doi:': {
          color: '#065F46',
          backgroundColor: '#D1FAE5',
          underline: false,
        },
      },
    }),
    []
  );

  const citationMarkdown = `Transformer architectures [cite://vaswani2017](cite://vaswani2017) revolutionised NLP. The original paper is available at [doi://10.48550](doi://10.48550) and builds on earlier attention work [cite://bahdanau2015](cite://bahdanau2015). See also https://arxiv.org for preprints.`;

  const chatStyle = useMemo<MarkdownStyle>(
    () => ({
      ...BASE_STYLE,
      link: { color: '#6366F1', underline: false },
      linkVariants: {
        '^user:': { color: '#4F46E5', backgroundColor: '#EEF2FF' },
        '^channel:': { color: '#0369A1', backgroundColor: '#E0F2FE' },
        '^tag:': { color: '#7C3AED', backgroundColor: '#F5F3FF' },
        '^team:': { color: '#B45309', backgroundColor: '#FFFBEB' },
      },
    }),
    []
  );

  const chatMarkdown = `[@alice](user://u1) mentioned you in [#product](channel://c-product). Assigned to [#team-eng](team://t-eng). Tagged as [#bug](tag://bug) and [#priority-high](tag://priority-high). Full ticket at https://linear.app/issue/ENG-42.`;

  const pathStyle = useMemo<MarkdownStyle>(
    () => ({
      ...BASE_STYLE,
      link: { color: '#6366F1', underline: false },
      linkVariants: {
        '\\/user\\/': { color: '#4F46E5', backgroundColor: '#EEF2FF' },
        '\\/channel\\/': { color: '#0369A1', backgroundColor: '#E0F2FE' },
      },
    }),
    []
  );

  const pathMarkdown = `The pattern is a regex matched against the **full URL**. Here the links use HTTPS with the entity type embedded in the path: [@alice](https://chat.myapp.com/user/42), [#general](https://chat.myapp.com/channel/general), and a plain [external link](https://example.com).`;

  const highlightAllStyle = useMemo<MarkdownStyle>(
    () => ({
      ...BASE_STYLE,
      link: { color: '#1D4ED8', backgroundColor: '#DBEAFE', underline: false },
      linkVariants: {
        '^user:': { color: '#1D4ED8', backgroundColor: '#BFDBFE' },
        '^channel:': { color: '#065F46', backgroundColor: '#D1FAE5' },
      },
    }),
    []
  );

  const highlightAllMarkdown = `Set \`link.backgroundColor\` to highlight every link, then override per-scheme. A [regular link](https://example.com), a [@person](user://u1), and a [#channel](channel://c1) all show chips.`;

  const minimalStyle = useMemo<MarkdownStyle>(
    () => ({
      ...BASE_STYLE,
      link: { color: '#6B7280', underline: false },
      linkVariants: {
        '^user:': { color: '#111827', underline: true },
        '^channel:': { color: '#2563EB', underline: true },
      },
    }),
    []
  );

  const minimalMarkdown = `No background chips — just colour + underline per scheme. Plain [link](https://example.com) uses the muted base. [@alice](user://u1) and [#announcements](channel://c1) stand out.`;

  return (
    <ScrollView
      style={styles.scrollView}
      contentContainerStyle={styles.content}
    >
      <Text style={styles.intro}>
        Each key in <Text style={styles.code}>linkVariants</Text> is a{' '}
        <Text style={styles.code}>RegExp</Text> pattern tested against the{' '}
        <Text style={styles.bold}>full URL</Text>. Longer patterns take
        precedence. Use <Text style={styles.code}>^user:</Text> to match custom
        schemes, or <Text style={styles.code}>/user/</Text> to match any https
        path containing <Text style={styles.code}>/user/</Text>.
      </Text>

      <SectionTitle>1. Slack-style mentions</SectionTitle>
      <SectionDesc>
        Anchored patterns <Text style={styles.codeSm}>^user:</Text> and{' '}
        <Text style={styles.codeSm}>^channel:</Text> match only URLs whose
        scheme starts with that prefix.
      </SectionDesc>
      <ConfigBlock>{`linkVariants: {
  '^user:':    { color: '#1264A3', backgroundColor: '#E8F5FB' },
  '^channel:': { color: '#1264A3', backgroundColor: '#E8F5FB' },
}`}</ConfigBlock>
      <Card>
        <EnrichedMarkdownText
          markdown={slackMarkdown}
          markdownStyle={slackStyle}
          onLinkPress={handleLinkPress}
        />
      </Card>

      <SectionTitle>2. Discord-style mentions</SectionTitle>
      <SectionDesc>
        Three anchored patterns — user (blue), channel (teal), role (purple).
      </SectionDesc>
      <ConfigBlock>{`linkVariants: {
  '^user:':    { color: '#5865F2', backgroundColor: '#D9DBFF' },
  '^channel:': { color: '#4F9A8A', backgroundColor: '#D4F1EB' },
  '^role:':    { color: '#8B5CF6', backgroundColor: '#EDE9FE' },
}`}</ConfigBlock>
      <Card>
        <EnrichedMarkdownText
          markdown={discordMarkdown}
          markdownStyle={discordStyle}
          onLinkPress={handleLinkPress}
        />
      </Card>

      <SectionTitle>3. Academic citations</SectionTitle>
      <SectionDesc>
        Soft background chips for <Text style={styles.codeSm}>cite:</Text> and{' '}
        <Text style={styles.codeSm}>doi:</Text> references — no underline.
      </SectionDesc>
      <ConfigBlock>{`linkVariants: {
  '^cite:': { color: '#92400E', backgroundColor: '#FEF9C3', underline: false },
  '^doi:':  { color: '#065F46', backgroundColor: '#D1FAE5', underline: false },
}`}</ConfigBlock>
      <Card>
        <EnrichedMarkdownText
          markdown={citationMarkdown}
          markdownStyle={citationStyle}
          onLinkPress={handleLinkPress}
        />
      </Card>

      <SectionTitle>4. Custom chat app</SectionTitle>
      <SectionDesc>
        Four anchored schemes: user, channel, tag, team — each with its own
        colour identity.
      </SectionDesc>
      <ConfigBlock>{`linkVariants: {
  '^user:':    { color: '#4F46E5', backgroundColor: '#EEF2FF' },
  '^channel:': { color: '#0369A1', backgroundColor: '#E0F2FE' },
  '^tag:':     { color: '#7C3AED', backgroundColor: '#F5F3FF' },
  '^team:':    { color: '#B45309', backgroundColor: '#FFFBEB' },
}`}</ConfigBlock>
      <Card>
        <EnrichedMarkdownText
          markdown={chatMarkdown}
          markdownStyle={chatStyle}
          onLinkPress={handleLinkPress}
        />
      </Card>

      <SectionTitle>5. Path-based matching</SectionTitle>
      <SectionDesc>
        If the URL scheme can't identify the type (e.g. all links are{' '}
        <Text style={styles.codeSm}>https://</Text>
        ), match on a path segment instead. The regex is tested against the full
        URL.
      </SectionDesc>
      <ConfigBlock>{`// URLs: https://chat.myapp.com/user/42
//       https://chat.myapp.com/channel/general
linkVariants: {
  '\\\\/user\\\\/':    { color: '#4F46E5', backgroundColor: '#EEF2FF' },
  '\\\\/channel\\\\/': { color: '#0369A1', backgroundColor: '#E0F2FE' },
}`}</ConfigBlock>
      <Card>
        <EnrichedMarkdownText
          markdown={pathMarkdown}
          markdownStyle={pathStyle}
          onLinkPress={handleLinkPress}
        />
      </Card>

      <SectionTitle>6. Background on all links</SectionTitle>
      <SectionDesc>
        Set <Text style={styles.code}>link.backgroundColor</Text> to highlight
        every link by default, then override per-scheme via{' '}
        <Text style={styles.code}>linkVariants</Text>.
      </SectionDesc>
      <ConfigBlock>{`link: {
  color: '#1D4ED8',
  backgroundColor: '#DBEAFE', // every link
  underline: false,
},
linkVariants: {
  '^user:':    { backgroundColor: '#BFDBFE' },
  '^channel:': { color: '#065F46', backgroundColor: '#D1FAE5' },
}`}</ConfigBlock>
      <Card>
        <EnrichedMarkdownText
          markdown={highlightAllMarkdown}
          markdownStyle={highlightAllStyle}
          onLinkPress={handleLinkPress}
        />
      </Card>

      <SectionTitle>7. Minimal — underline only</SectionTitle>
      <SectionDesc>
        No background fill. Variants differ only in colour and whether underline
        is shown.
      </SectionDesc>
      <ConfigBlock>{`link: { color: '#6B7280', underline: false },
linkVariants: {
  '^user:':    { color: '#111827', underline: true },
  '^channel:': { color: '#2563EB', underline: true },
}`}</ConfigBlock>
      <Card>
        <EnrichedMarkdownText
          markdown={minimalMarkdown}
          markdownStyle={minimalStyle}
          onLinkPress={handleLinkPress}
        />
      </Card>

      <View style={styles.tipBox}>
        <Text style={styles.tipTitle}>Tap any mention above</Text>
        <Text style={styles.tipBody}>
          The <Text style={styles.code}>onLinkPress</Text> callback still
          receives the full URL — parse it however your app needs:
        </Text>
        <ConfigBlock>{`onLinkPress={({ url }) => {
  if (url.startsWith('user://'))    return openProfile(url);
  if (url.includes('/user/'))       return openProfile(url);
  Linking.openURL(url);
}}`}</ConfigBlock>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scrollView: {
    flex: 1,
    backgroundColor: '#F9FAFB',
  },
  content: {
    padding: 16,
    paddingBottom: 40,
  },
  intro: {
    fontSize: 14,
    color: '#374151',
    lineHeight: 22,
    marginBottom: 24,
    backgroundColor: '#EFF6FF',
    borderRadius: 8,
    padding: 12,
    borderLeftWidth: 3,
    borderLeftColor: '#3B82F6',
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#111827',
    marginTop: 24,
    marginBottom: 4,
  },
  sectionDesc: {
    fontSize: 13,
    color: '#6B7280',
    lineHeight: 19,
    marginBottom: 8,
  },
  configBlock: {
    backgroundColor: '#1F2937',
    borderRadius: 6,
    padding: 10,
    marginBottom: 8,
  },
  configText: {
    fontFamily: 'CourierPrime-Regular',
    fontSize: 12,
    color: '#D1FAE5',
    lineHeight: 18,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 10,
    padding: 14,
    borderWidth: 1,
    borderColor: '#E5E7EB',
  },
  tipBox: {
    marginTop: 32,
    backgroundColor: '#FFFBEB',
    borderRadius: 8,
    padding: 12,
    borderLeftWidth: 3,
    borderLeftColor: '#F59E0B',
  },
  tipTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#92400E',
    marginBottom: 4,
  },
  tipBody: {
    fontSize: 13,
    color: '#78350F',
    lineHeight: 19,
    marginBottom: 8,
  },
  code: {
    fontFamily: 'CourierPrime-Regular',
    fontSize: 13,
    backgroundColor: '#F3F4F6',
    color: '#6D28D9',
  },
  codeSm: {
    fontFamily: 'CourierPrime-Regular',
    fontSize: 12,
    backgroundColor: '#F3F4F6',
    color: '#6D28D9',
  },
  bold: {
    fontWeight: '700',
  },
});
