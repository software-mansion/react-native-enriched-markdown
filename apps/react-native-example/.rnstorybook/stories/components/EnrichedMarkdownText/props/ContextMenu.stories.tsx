import React from 'react';
import type { EnrichedMarkdownTextProps } from 'react-native-enriched-markdown';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN =
  'Select this text to open the context menu with a custom action.';

type ContextMenuOnPress = NonNullable<
  EnrichedMarkdownTextProps['contextMenuItems']
>[number]['onPress'];

type ContextMenuStoryExtra = {
  showCustomItem: boolean;
  onContextMenuItemPress?: ContextMenuOnPress;
};

const argTypes = {
  showCustomItem: {
    control: 'boolean',
    description:
      'Adds a custom contextMenuItems entry alongside built-in actions.',
  },
  onContextMenuItemPress: { action: 'contextMenuItem.onPress' },
};

export default storyMeta('Props', 'Context Menu');

export const Default: TextStory<ContextMenuStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    showCustomItem: true,
  },
  argTypes,
  render: ({ showCustomItem, onContextMenuItemPress, ...args }) => {
    const contextMenuItems: EnrichedMarkdownTextProps['contextMenuItems'] =
      showCustomItem
        ? [
            {
              text: 'Log selection',
              onPress: onContextMenuItemPress ?? (() => {}),
            },
          ]
        : undefined;

    return (
      <EnrichedMarkdownTextStory
        title="Context Menu"
        description="contextMenuItems adds custom entries to the native selection menu. Built-in copy actions are under Props / Selection Menu."
        {...args}
        contextMenuItems={contextMenuItems}
      />
    );
  },
};
