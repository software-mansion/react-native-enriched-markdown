export type RawMessage = {
  nick: string;
  time: string;
  message: string;
};

export type ChannelData = {
  messages: RawMessage[];
  newFromIndex: number;
};

export type MessageItem =
  | { id: number; kind: 'message'; nick: string; time: string; message: string }
  | { id: number; kind: 'divider'; count: number };

export type MentionItem = {
  name: string;
  url: string;
};

export type BubbleContextMenuItem = {
  text: string;
  icon?: string;
  onPress: (args: { text: string }) => void;
};
