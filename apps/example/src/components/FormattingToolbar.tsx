import { useCallback, useRef, useState } from 'react';
import {
  Text,
  View,
  TouchableOpacity,
  StyleSheet,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import {
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';
import { LinkModal } from './LinkModal';
import BoldIcon from '../assets/icons/format_bold_24dp.svg';
import ItalicIcon from '../assets/icons/format_italic_24dp.svg';
import UnderlineIcon from '../assets/icons/format_underlined_24dp.svg';
import StrikethroughIcon from '../assets/icons/strikethrough_s_24dp.svg';
import SpoilerIcon from '../assets/icons/visibility_off_24dp.svg';
import AddLinkIcon from '../assets/icons/add_link_24dp.svg';

interface FormattingToolbarProps {
  state: StyleState | null;
  inputRef: React.RefObject<EnrichedMarkdownTextInputInstance | null>;
  hasSelection: boolean;
  mentionIndicators?: string[];
  style?: StyleProp<ViewStyle>;
  testID?: string;
}

const ICON_COLOR = '#001A72';
const ICON_SIZE = 18;

const ITEMS = [
  {
    styleKey: 'bold',
    action: 'toggleBold',
    icon: <BoldIcon width={ICON_SIZE} height={ICON_SIZE} color={ICON_COLOR} />,
  },
  {
    styleKey: 'italic',
    action: 'toggleItalic',
    icon: (
      <ItalicIcon width={ICON_SIZE} height={ICON_SIZE} color={ICON_COLOR} />
    ),
  },
  {
    styleKey: 'underline',
    action: 'toggleUnderline',
    icon: (
      <UnderlineIcon width={ICON_SIZE} height={ICON_SIZE} color={ICON_COLOR} />
    ),
  },
  {
    styleKey: 'strikethrough',
    action: 'toggleStrikethrough',
    icon: (
      <StrikethroughIcon
        width={ICON_SIZE}
        height={ICON_SIZE}
        color={ICON_COLOR}
      />
    ),
  },
  {
    styleKey: 'spoiler',
    action: 'toggleSpoiler',
    icon: (
      <SpoilerIcon width={ICON_SIZE} height={ICON_SIZE} color={ICON_COLOR} />
    ),
  },
] as const;

const LINK_ICON = (
  <AddLinkIcon width={ICON_SIZE} height={ICON_SIZE} color={ICON_COLOR} />
);

export function FormattingToolbar({
  state,
  inputRef,
  hasSelection,
  mentionIndicators,
  style,
  testID,
}: FormattingToolbarProps) {
  const [linkModalVisible, setLinkModalVisible] = useState(false);
  const selectionAtOpen = useRef(false);

  const handleLinkButtonPress = useCallback(() => {
    if (state?.link.isActive) {
      inputRef.current?.removeLink();
    } else {
      selectionAtOpen.current = hasSelection;
      setLinkModalVisible(true);
    }
  }, [state?.link.isActive, hasSelection, inputRef]);

  const handleLinkSubmit = useCallback(
    (text: string, url: string) => {
      setLinkModalVisible(false);
      if (!url) return;
      if (selectionAtOpen.current) {
        inputRef.current?.setLink(url);
      } else {
        inputRef.current?.insertLink(text, url);
      }
    },
    [inputRef]
  );

  return (
    <>
      <View style={[styles.toolbar, style]} testID={testID}>
        {ITEMS.map(({ styleKey, action, icon }) => (
          <TouchableOpacity
            key={styleKey}
            style={[
              styles.toolbarButton,
              state?.[styleKey].isActive && styles.toolbarButtonActive,
            ]}
            onPress={() => inputRef.current?.[action]()}
            testID={`toolbar-${styleKey}`}
          >
            {icon}
          </TouchableOpacity>
        ))}
        <TouchableOpacity
          style={[
            styles.toolbarButton,
            state?.link.isActive && styles.toolbarButtonActive,
          ]}
          onPress={handleLinkButtonPress}
          testID="toolbar-link"
        >
          {LINK_ICON}
        </TouchableOpacity>
        {mentionIndicators?.map((indicator) => (
          <TouchableOpacity
            key={indicator}
            style={[styles.toolbarButton, styles.mentionButton]}
            onPress={() => inputRef.current?.startMention(indicator)}
            testID={`toolbar-mention-${indicator}`}
          >
            <Text style={styles.mentionButtonText}>{indicator}</Text>
          </TouchableOpacity>
        ))}
      </View>
      <LinkModal
        visible={linkModalVisible}
        initialText=""
        initialUrl=""
        onClose={() => setLinkModalVisible(false)}
        onSubmit={handleLinkSubmit}
      />
    </>
  );
}

const styles = StyleSheet.create({
  toolbar: {
    flexDirection: 'row',
    gap: 4,
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#E5E7EB',
    backgroundColor: '#F9FAFB',
  },
  toolbarButton: {
    minWidth: 34,
    height: 30,
    borderRadius: 6,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 6,
    backgroundColor: 'transparent',
  },
  toolbarButtonActive: {
    backgroundColor: '#E2F8EB',
  },
  mentionButton: {
    backgroundColor: '#EEF2FF',
  },
  mentionButtonText: {
    color: ICON_COLOR,
    fontSize: 15,
    fontWeight: '700',
  },
});
