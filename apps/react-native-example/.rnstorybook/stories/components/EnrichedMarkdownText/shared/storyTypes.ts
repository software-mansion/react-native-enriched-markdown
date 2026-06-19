import type { ComponentProps, ReactElement } from 'react';
import type { Meta, StoryObj } from '@storybook/react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

export type TextStoryMeta = Meta<typeof EnrichedMarkdownText>;

/** Component props merged with Storybook-only control args. */
export type StoryArgs<TExtra extends Record<string, unknown> = {}> =
  ComponentProps<typeof EnrichedMarkdownText> & TExtra;

type TextStoryBase = Omit<
  StoryObj<TextStoryMeta>,
  'args' | 'render' | 'argTypes'
>;

/** TExtra = Storybook-only control args (e.g. style knobs) merged with component props. */
export type TextStory<TExtra extends Record<string, unknown> = {}> =
  TextStoryBase & {
    args?: StoryArgs<TExtra>;
    render: (args: StoryArgs<TExtra>) => ReactElement;
    argTypes?: Record<string, unknown>;
  };
