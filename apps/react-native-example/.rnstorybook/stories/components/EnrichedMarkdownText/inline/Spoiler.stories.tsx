import React, { useState } from 'react';
import { Button, StyleSheet, View } from 'react-native';
import {
  EnrichedMarkdownText,
  type EnrichedMarkdownTextProps,
} from 'react-native-enriched-markdown';
import { MarkdownStoryLayout } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  numberControl,
  spoilerStyledDefaults,
  type SpoilerStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toSpoilerStyle,
} from '../shared/storybookStyleBuilders';
import type { StoryArgs, TextStory } from '../shared/storyTypes';

type SpoilerStoryExtra = SpoilerStyleControls & {
  spoilerOverlay?: 'particles' | 'solid';
};

type SpoilerStoryArgs = StoryArgs<SpoilerStoryExtra>;

type SpoilerStoryProps = Omit<EnrichedMarkdownTextProps, 'markdownStyle'> & {
  title: string;
  description: string;
  style?: EnrichedMarkdownTextProps['markdownStyle'];
  /** Storybook-only callback fired when Reload Spoiler is pressed. */
  onReloadSpoiler?: () => void;
};

function SpoilerStory({
  title,
  description,
  markdown: initialMarkdown,
  spoilerOverlay = 'particles',
  onReloadSpoiler,
  style,
  ...props
}: SpoilerStoryProps) {
  const [markdown, setMarkdown] = useState(initialMarkdown);
  const [reloadNonce, setReloadNonce] = useState(0);
  const spoilerStyleKey = style?.spoiler ? JSON.stringify(style.spoiler) : '';

  return (
    <View>
      <MarkdownStoryLayout
        title={title}
        description={description}
        markdown={markdown}
        onMarkdownChange={setMarkdown}
        output={
          <EnrichedMarkdownText
            // Remount preview when spoiler style changes; overlays don't pick up markdownStyle.spoiler live in Storybook.
            key={`${spoilerStyleKey}:${reloadNonce}`}
            markdown={markdown}
            markdownStyle={style}
            spoilerOverlay={spoilerOverlay}
            {...props}
          />
        }
      />
      <View style={styles.reloadButton}>
        <Button
          onPress={() => {
            setReloadNonce((n) => n + 1);
            onReloadSpoiler?.();
          }}
          title="Reload Spoiler"
        />
      </View>
    </View>
  );
}

const INLINE_MARKDOWN = `The password is ||swordfish|| and the code is ||42||.

Spoiler with **bold** inside: ||The tree is named **Methuselah** and is over *4,850 years old*||.`;

const BLOCK_MARKDOWN = `||The entire Amazon rainforest produces about **20% of the world's oxygen**, but recent studies suggest that the true figure may be closer to *6-9%* because the forest also consumes a significant amount of oxygen through decomposition. Nevertheless, the Amazon remains the single largest tropical rainforest on Earth, spanning **5.5 million square kilometers** across nine countries.||`;

const argTypes = {
  spoilerOverlay: {
    options: ['particles', 'solid'],
    control: { type: 'inline-radio' },
    description: 'spoilerOverlay — particles or solid concealment preset.',
  },
  color: {
    control: 'color',
    description: 'markdownStyle.spoiler.color',
  },
  particleDensity: {
    if: { arg: 'spoilerOverlay', eq: 'particles' },
    ...numberControl('markdownStyle.spoiler.particles.density', {
      min: 1,
      max: 24,
      step: 1,
    }),
  },
  particleSpeed: {
    if: { arg: 'spoilerOverlay', eq: 'particles' },
    ...numberControl('markdownStyle.spoiler.particles.speed', {
      min: 5,
      max: 60,
      step: 5,
    }),
  },
  solidBorderRadius: {
    if: { arg: 'spoilerOverlay', eq: 'solid' },
    ...numberControl('markdownStyle.spoiler.solid.borderRadius', {
      min: 0,
      max: 16,
      step: 1,
    }),
  },
  onReloadSpoiler: { action: 'onReloadSpoiler' },
};

function renderSpoiler(
  title: string,
  description: string,
  args: SpoilerStoryArgs
) {
  const { spoilerOverlay = 'particles', ...storyArgs } = args;
  const { controls, rest } = splitStyleControls(
    storyArgs,
    spoilerStyledDefaults
  );

  return (
    <SpoilerStory
      title={title}
      description={description}
      {...rest}
      spoilerOverlay={spoilerOverlay}
      style={{ spoiler: toSpoilerStyle(controls) }}
    />
  );
}

const spoilerStoryBase = {
  argTypes,
  args: {
    spoilerOverlay: 'particles' as const,
    ...spoilerStyledDefaults,
  },
};

export default storyMeta('Inline', 'Spoiler');

export const Inline: TextStory<SpoilerStoryExtra> = {
  ...spoilerStoryBase,
  args: {
    ...spoilerStoryBase.args,
    markdown: INLINE_MARKDOWN,
  },
  render: (args) =>
    renderSpoiler(
      'Inline Spoiler',
      '||hidden text|| inside a paragraph, including inline **bold** and *italic*. Tap to reveal. Use Reload Spoiler to reset spoilers after revealing them.',
      args
    ),
};

export const Block: TextStory<SpoilerStoryExtra> = {
  ...spoilerStoryBase,
  args: {
    ...spoilerStoryBase.args,
    markdown: BLOCK_MARKDOWN,
  },
  render: (args) =>
    renderSpoiler(
      'Block Spoiler',
      'A full paragraph wrapped in ||...|| on its own line. Tap to reveal. Use Reload Spoiler to reset spoilers after revealing them.',
      args
    ),
};

const styles = StyleSheet.create({
  reloadButton: {
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
});
