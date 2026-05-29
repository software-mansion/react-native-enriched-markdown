const MAIN_TEXT = '#001A72';
const USER_MENTION_BG = '#C2E2FF';
const CHANNEL_MENTION_BG = '#AAD3FF';

const FONT_SIZE = 13;
const LINE_HEIGHT = 18;
const BLOCK_MARGIN = 6;
const MARGIN_BOTTOM = 2;

export const MARKDOWN_STYLE = {
  paragraph: {
    fontSize: FONT_SIZE,
    lineHeight: LINE_HEIGHT,
    marginTop: BLOCK_MARGIN,
    marginBottom: MARGIN_BOTTOM,
  },
  h1: {
    fontSize: FONT_SIZE + 4,
    lineHeight: LINE_HEIGHT + 4,
    marginTop: BLOCK_MARGIN,
    marginBottom: MARGIN_BOTTOM,
  },
  h2: {
    fontSize: FONT_SIZE + 3,
    lineHeight: LINE_HEIGHT + 3,
    marginTop: BLOCK_MARGIN,
    marginBottom: MARGIN_BOTTOM,
  },
  h3: {
    fontSize: FONT_SIZE + 2,
    lineHeight: LINE_HEIGHT + 2,
    marginTop: BLOCK_MARGIN,
    marginBottom: MARGIN_BOTTOM,
  },
  h4: {
    fontSize: FONT_SIZE + 1,
    lineHeight: LINE_HEIGHT + 1,
    marginTop: BLOCK_MARGIN,
    marginBottom: MARGIN_BOTTOM,
  },
  h5: {
    fontSize: FONT_SIZE,
    lineHeight: LINE_HEIGHT,
    marginTop: BLOCK_MARGIN,
    marginBottom: MARGIN_BOTTOM,
  },
  h6: {
    fontSize: FONT_SIZE,
    lineHeight: LINE_HEIGHT,
    marginTop: BLOCK_MARGIN,
    marginBottom: MARGIN_BOTTOM,
  },
  blockquote: {
    fontSize: FONT_SIZE,
    lineHeight: LINE_HEIGHT,
    marginTop: BLOCK_MARGIN,
    marginBottom: MARGIN_BOTTOM,
  },
  list: {
    fontSize: FONT_SIZE,
    lineHeight: LINE_HEIGHT,
    marginTop: BLOCK_MARGIN,
    marginBottom: MARGIN_BOTTOM,
  },
  link: { color: '#2563EB', underline: true },
  linkVariants: {
    '^user:': {
      color: MAIN_TEXT,
      backgroundColor: USER_MENTION_BG,
      underline: false,
    },
    '^channel:': {
      color: MAIN_TEXT,
      backgroundColor: CHANNEL_MENTION_BG,
      underline: false,
    },
  },
};
