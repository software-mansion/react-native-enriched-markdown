import type { MarkdownTextInputStyle } from 'react-native-enriched-markdown';
import type { InputStoryArgs } from './storyTypes';
import type {
  InputEmStyleControls,
  InputLinkStyleControls,
  InputLinkVariantsDemoControls,
  InputSpoilerStyleControls,
  InputStrongStyleControls,
} from './storybookInputStyles';

export function splitStyleControls<TControls extends Record<string, unknown>>(
  args: InputStoryArgs<TControls>,
  defaults: TControls
): { controls: TControls; rest: InputStoryArgs } {
  const controls = { ...defaults };
  const rest = { ...args };
  for (const key of Object.keys(defaults) as (keyof TControls)[]) {
    const value = args[key as keyof typeof args];
    if (value !== undefined) {
      controls[key] = value as TControls[keyof TControls];
    }
    delete rest[key as string];
  }
  return { controls, rest: rest as InputStoryArgs };
}

export function toInputStrongStyle(
  controls: InputStrongStyleControls
): NonNullable<MarkdownTextInputStyle['strong']> {
  return { color: controls.color };
}

export function toInputEmStyle(
  controls: InputEmStyleControls
): NonNullable<MarkdownTextInputStyle['em']> {
  return { color: controls.color };
}

export function toInputLinkStyle(
  controls: InputLinkStyleControls
): NonNullable<MarkdownTextInputStyle['link']> {
  return {
    color: controls.color,
    underline: controls.underline,
    backgroundColor: controls.backgroundColor,
  };
}

export function toInputSpoilerStyle(
  controls: InputSpoilerStyleControls
): NonNullable<MarkdownTextInputStyle['spoiler']> {
  return {
    color: controls.color,
    backgroundColor: controls.backgroundColor,
  };
}

export function toInputLinkVariantsDemoStyle(
  controls: InputLinkVariantsDemoControls
): Pick<MarkdownTextInputStyle, 'link' | 'linkVariants'> {
  const {
    jiraVariantColor,
    jiraVariantUnderline,
    jiraVariantBackgroundColor,
    sftpVariantColor,
    sftpVariantUnderline,
    sftpVariantBackgroundColor,
    notionVariantColor,
    notionVariantUnderline,
    notionVariantBackgroundColor,
    ...linkControls
  } = controls;

  return {
    link: toInputLinkStyle(linkControls),
    linkVariants: {
      '^jira:': {
        color: jiraVariantColor,
        underline: jiraVariantUnderline,
        backgroundColor: jiraVariantBackgroundColor,
      },
      '^sftp:': {
        color: sftpVariantColor,
        underline: sftpVariantUnderline,
        backgroundColor: sftpVariantBackgroundColor,
      },
      '^notion:': {
        color: notionVariantColor,
        underline: notionVariantUnderline,
        backgroundColor: notionVariantBackgroundColor,
      },
    },
  };
}
