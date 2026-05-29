import type { ChannelData, MentionItem, MessageItem } from './types';

export const MY_NICK = 'me';

export const USER_MENTIONS: MentionItem[] = [
  { name: 'dave', url: 'user://u_1' },
  { name: 'jane', url: 'user://u_2' },
  { name: 'alice', url: 'user://u_3' },
  { name: 'bob', url: 'user://u_4' },
];

export const CHANNEL_MENTIONS: MentionItem[] = [
  { name: 'random', url: 'channel://random' },
  { name: 'swm-stand', url: 'channel://swm-stand' },
  { name: 'general', url: 'channel://general' },
];

export const CHANNEL_DATA: Record<string, ChannelData> = {
  'random': {
    newFromIndex: 6,
    messages: [
      {
        nick: 'bob',
        time: '09:12',
        message:
          '**App.js is here!**\n\nJust arrived in Krakow. Who else is already at the venue?',
      },
      {
        nick: 'alice',
        time: '09:13',
        message: 'Already here - the venue looks incredible.',
      },
      {
        nick: 'carol',
        time: '09:14',
        message:
          '> Just arrived in Krakow. Who else is already at the venue?\n\nFirst App.js for me. A bit overwhelmed honestly.',
      },
      {
        nick: 'bob',
        time: '09:15',
        message: '[@carol](user://u_5) Welcome! It only gets better from here.',
      },
      {
        nick: 'dave',
        time: '09:58',
        message:
          'Keynote starting in a few minutes - good seats still in the middle rows.',
      },
      {
        nick: 'carol',
        time: '09:59',
        message: 'On my way!',
      },
      // ── new messages below ──
      {
        nick: 'alice',
        time: '11:48',
        message: 'Enriched demo was great - congrats team.',
      },
      {
        nick: 'dave',
        time: '11:49',
        message: 'Thank you! Now I can relax and enjoy the rest.',
      },
      {
        nick: 'bob',
        time: '11:50',
        message:
          "**Do Not Miss**\n\n||Iwo Plaza's - WebGPU Shaders for React Native - after lunch ||",
      },
      {
        nick: 'dave',
        time: '11:51',
        message: 'Already claimed front row seats.',
      },
      { nick: 'alice', time: '11:51', message: 'See you all there.' },
    ],
  },
  'swm-stand': {
    newFromIndex: 9,
    messages: [
      {
        nick: 'alice',
        time: '08:45',
        message:
          '**SWM Stand**\n\nWe are set up near the main entrance. Come say hi!',
      },
      {
        nick: 'bob',
        time: '08:46',
        message:
          'Stickers, goodies from our products and a few surprises ready to go.',
      },
      {
        nick: 'carol',
        time: '08:47',
        message:
          '> Stickers, goodies from our products\n\n[@bob](user://u_4) Detour stickers are looking great btw.',
      },
      {
        nick: 'dave',
        time: '08:47',
        message: 'Can confirm. Already grabbed a set.',
      },
      {
        nick: 'alice',
        time: '08:48',
        message:
          '[@dave](user://u_6) You were supposed to wait for the announcement...',
      },
      {
        nick: 'bob',
        time: '08:49',
        message: '*Totally* ~~not~~ bringing extra goodies out at 3pm.',
      },
      { nick: 'carol', time: '08:49', message: '[@bob](user://u_4) Noted.' },
      { nick: 'dave', time: '08:50', message: 'My lips are sealed.' },
      {
        nick: 'alice',
        time: '08:50',
        message: "You'll also get to meet our product teams - come find us!",
      },
      // ── new messages below ──
      {
        nick: 'carol',
        time: '12:02',
        message: 'Stand is getting busy - loving it.',
      },
      {
        nick: 'dave',
        time: '12:03',
        message: 'The Detour sticker queue is real.',
      },
      {
        nick: 'alice',
        time: '12:04',
        message:
          '**Update**\n\n|| Some goodies running __low__ - stickers still available ||',
      },
      {
        nick: 'bob',
        time: '12:05',
        message: 'Thank you everyone for stopping by!',
      },
    ],
  },
};

export function buildMessages(channel: string): MessageItem[] {
  const data = CHANNEL_DATA[channel];
  if (!data) return [];

  const { messages, newFromIndex } = data;
  const newCount = messages.length - newFromIndex;
  const result: MessageItem[] = [];
  let id = 1;

  messages.forEach((msg, i) => {
    if (i === newFromIndex && newCount > 0) {
      result.push({ id: id++, kind: 'divider', count: newCount });
    }
    result.push({ id: id++, kind: 'message', ...msg });
  });

  return result;
}
