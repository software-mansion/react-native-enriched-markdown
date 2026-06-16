import { processColor, type ColorValue } from 'react-native';
import type {
  LinkStyle,
  MarkdownTextInputStyle,
} from './EnrichedMarkdownTextInput';
import { normalizeLinkVariantEntries } from './linkVariantUtils';
import { normalizeColor } from './styleUtils';

interface LinkVariantEntryInternal {
  pattern: string;
  color: ColorValue;
  underline: boolean;
  backgroundColor: ColorValue;
}

interface MarkdownTextInputStyleInternal {
  strong: {
    color?: ColorValue;
  };
  em: {
    color?: ColorValue;
  };
  link: {
    color: ColorValue;
    underline: boolean;
    backgroundColor: ColorValue;
  };
  linkVariants: LinkVariantEntryInternal[];
  spoiler: {
    color: ColorValue;
    backgroundColor: ColorValue;
  };
}

const DEFAULT_LINK_COLOR = '#2563EB';
const DEFAULT_LINK_BG_COLOR = 'transparent';
const DEFAULT_SPOILER_COLOR = '#374151';
const DEFAULT_SPOILER_BG_COLOR = '#E5E7EB';

const defaultInternal: MarkdownTextInputStyleInternal = Object.freeze({
  strong: {
    color: undefined,
  },
  em: {
    color: undefined,
  },
  link: {
    color: processColor(DEFAULT_LINK_COLOR)!,
    underline: true,
    backgroundColor: processColor(DEFAULT_LINK_BG_COLOR)!,
  },
  linkVariants: [],
  spoiler: {
    color: processColor(DEFAULT_SPOILER_COLOR)!,
    backgroundColor: processColor(DEFAULT_SPOILER_BG_COLOR)!,
  },
});

let cachedInput: MarkdownTextInputStyle | undefined;
let cachedResult: MarkdownTextInputStyleInternal | undefined;

function normalizeInputLinkStyle(
  style: LinkStyle | undefined,
  fallback: MarkdownTextInputStyleInternal['link']
): MarkdownTextInputStyleInternal['link'] {
  return {
    color: normalizeColor(style?.color) ?? fallback.color,
    underline: style?.underline ?? fallback.underline,
    backgroundColor:
      normalizeColor(style?.backgroundColor) ?? fallback.backgroundColor,
  };
}

export const normalizeMarkdownTextInputStyle = (
  style?: MarkdownTextInputStyle
): MarkdownTextInputStyleInternal => {
  if (!style || Object.keys(style).length === 0) {
    return defaultInternal;
  }

  if (style === cachedInput && cachedResult) {
    return cachedResult;
  }

  const linkBase = normalizeInputLinkStyle(style.link, defaultInternal.link);
  const result: MarkdownTextInputStyleInternal = {
    strong: {
      color: normalizeColor(style.strong?.color),
    },
    em: {
      color: normalizeColor(style.em?.color),
    },
    link: linkBase,
    linkVariants: normalizeLinkVariantEntries(style.linkVariants).map(
      ([pattern, override]) => ({
        pattern,
        color: normalizeColor(override.color) ?? linkBase.color,
        underline: override.underline ?? linkBase.underline,
        backgroundColor:
          normalizeColor(override.backgroundColor) ??
          defaultInternal.link.backgroundColor,
      })
    ),
    spoiler: {
      color:
        normalizeColor(style.spoiler?.color) ?? defaultInternal.spoiler.color,
      backgroundColor:
        normalizeColor(style.spoiler?.backgroundColor) ??
        defaultInternal.spoiler.backgroundColor,
    },
  };

  cachedInput = style;
  cachedResult = result;
  return result;
};
