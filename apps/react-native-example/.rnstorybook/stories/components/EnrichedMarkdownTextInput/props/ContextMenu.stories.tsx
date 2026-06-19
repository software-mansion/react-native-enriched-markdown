import React from 'react';
import type { EnrichedMarkdownTextInputProps } from 'react-native-enriched-markdown';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

const MARKDOWN =
  'Select this text to open the context menu with a custom action.';

type ContextMenuOnPress = NonNullable<
  EnrichedMarkdownTextInputProps['contextMenuItems']
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

export const Default: InputStory<ContextMenuStoryExtra> = {
  args: {
    initialMarkdown: MARKDOWN,
    showCustomItem: true,
  },
  argTypes,
  render: ({ showCustomItem, onContextMenuItemPress, ...args }) => {
    const contextMenuItems: EnrichedMarkdownTextInputProps['contextMenuItems'] =
      showCustomItem
        ? [
            {
              text: 'Log selection',
              onPress: onContextMenuItemPress ?? (() => {}),
            },
          ]
        : undefined;

    return (
      <EnrichedMarkdownTextInputStory
        title="Context Menu"
        description="contextMenuItems adds custom entries to the native selection menu. Custom items require iOS 16+; earlier iOS versions ignore this prop."
        {...args}
        contextMenuItems={contextMenuItems}
      />
    );
  },
};
