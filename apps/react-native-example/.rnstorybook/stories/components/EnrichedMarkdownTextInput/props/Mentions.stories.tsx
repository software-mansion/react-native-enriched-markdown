import React from 'react';
import {
  DEFAULT_MENTION_CHANNELS,
  DEFAULT_MENTION_USERS,
  MentionsStory,
} from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

type MentionsStoryExtra = {
  userNames: string[];
  channelNames: string[];
};

export default storyMeta('Props', 'Mentions');

export const Default: InputStory<MentionsStoryExtra> = {
  args: {
    userNames: DEFAULT_MENTION_USERS.map((u) => u.name),
    channelNames: DEFAULT_MENTION_CHANNELS.map((c) => c.name),
  },
  argTypes: {
    userNames: {
      control: 'multi-select',
      options: DEFAULT_MENTION_USERS.map((u) => u.name),
      description: 'Users available for @ mentions.',
    },
    channelNames: {
      control: 'multi-select',
      options: DEFAULT_MENTION_CHANNELS.map((c) => c.name),
      description: 'Channels available for # mentions.',
    },
  },
  render: ({ userNames, channelNames }) => (
    <MentionsStory
      title="Mentions"
      description={`Type @ to mention a user or # to mention a channel. Tap a suggestion to insert it. Toolbar buttons also trigger mention flows.

Mentions are styled links — linkVariants in markdownStyle maps URL patterns to custom colors.`}
      users={DEFAULT_MENTION_USERS.filter((u) => userNames?.includes(u.name))}
      channels={DEFAULT_MENTION_CHANNELS.filter((c) =>
        channelNames?.includes(c.name)
      )}
    />
  ),
};
