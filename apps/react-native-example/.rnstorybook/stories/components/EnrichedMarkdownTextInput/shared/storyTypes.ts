import type { ComponentProps, ReactElement } from 'react';
import type { Meta, StoryObj } from '@storybook/react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export type InputStoryMeta = Meta<typeof EnrichedMarkdownTextInput>;

/** Component props merged with Storybook-only control args. */
export type InputStoryArgs<TExtra extends Record<string, unknown> = {}> = Omit<
  ComponentProps<typeof EnrichedMarkdownTextInput>,
  'markdownStyle'
> & {
  initialMarkdown?: string;
} & TExtra;

type InputStoryBase = Omit<
  StoryObj<InputStoryMeta>,
  'args' | 'render' | 'argTypes'
>;

/** TExtra = Storybook-only control args (e.g. markdownStyle knobs) merged with component props. */
export type InputStory<TExtra extends Record<string, unknown> = {}> =
  InputStoryBase & {
    args?: InputStoryArgs<TExtra>;
    render: (args: InputStoryArgs<TExtra>) => ReactElement;
    argTypes?: Record<string, unknown>;
  };
