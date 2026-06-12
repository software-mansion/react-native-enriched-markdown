export type InputStrongStyleControls = {
  color: string;
};

export const inputStrongDefaults: InputStrongStyleControls = {
  color: '#1D4ED8',
};

export type InputEmStyleControls = {
  color: string;
};

export const inputEmDefaults: InputEmStyleControls = {
  color: '#7C3AED',
};

export type InputLinkStyleControls = {
  color: string;
  underline: boolean;
  backgroundColor: string;
};

export const inputLinkDefaults: InputLinkStyleControls = {
  color: '#2563EB',
  underline: true,
  backgroundColor: 'transparent',
};

export type InputLinkVariantsDemoControls = InputLinkStyleControls & {
  jiraVariantColor: string;
  jiraVariantUnderline: boolean;
  jiraVariantBackgroundColor: string;
  sftpVariantColor: string;
  sftpVariantUnderline: boolean;
  sftpVariantBackgroundColor: string;
  notionVariantColor: string;
  notionVariantUnderline: boolean;
  notionVariantBackgroundColor: string;
};

export const inputLinkVariantsDemoDefaults: InputLinkVariantsDemoControls = {
  ...inputLinkDefaults,
  jiraVariantColor: '#0052CC',
  jiraVariantUnderline: false,
  jiraVariantBackgroundColor: '#DEEBFF',
  sftpVariantColor: '#065F46',
  sftpVariantUnderline: false,
  sftpVariantBackgroundColor: '#D1FAE5',
  notionVariantColor: '#6B21A8',
  notionVariantUnderline: false,
  notionVariantBackgroundColor: '#F3E8FF',
};

export type InputSpoilerStyleControls = {
  color: string;
  backgroundColor: string;
};

export const inputSpoilerDefaults: InputSpoilerStyleControls = {
  color: '#FFFFFF',
  backgroundColor: '#111827',
};

export const inputLinkBaseArgTypes = {
  color: {
    control: 'color' as const,
    description: 'markdownStyle.link.color',
  },
  underline: {
    control: 'boolean' as const,
    description: 'markdownStyle.link.underline',
  },
  backgroundColor: {
    control: 'color' as const,
    description: 'markdownStyle.link.backgroundColor',
  },
};

export const inputLinkVariantsArgTypes = {
  ...inputLinkBaseArgTypes,
  color: {
    control: 'color' as const,
    description: 'markdownStyle.link.color (fallback for unmatched URLs)',
  },
  jiraVariantColor: {
    control: 'color' as const,
    description: 'markdownStyle.linkVariants["^jira:"].color',
  },
  jiraVariantUnderline: {
    control: 'boolean' as const,
    description: 'markdownStyle.linkVariants["^jira:"].underline',
  },
  jiraVariantBackgroundColor: {
    control: 'color' as const,
    description: 'markdownStyle.linkVariants["^jira:"].backgroundColor',
  },
  sftpVariantColor: {
    control: 'color' as const,
    description: 'markdownStyle.linkVariants["^sftp:"].color',
  },
  sftpVariantUnderline: {
    control: 'boolean' as const,
    description: 'markdownStyle.linkVariants["^sftp:"].underline',
  },
  sftpVariantBackgroundColor: {
    control: 'color' as const,
    description: 'markdownStyle.linkVariants["^sftp:"].backgroundColor',
  },
  notionVariantColor: {
    control: 'color' as const,
    description: 'markdownStyle.linkVariants["^notion:"].color',
  },
  notionVariantUnderline: {
    control: 'boolean' as const,
    description: 'markdownStyle.linkVariants["^notion:"].underline',
  },
  notionVariantBackgroundColor: {
    control: 'color' as const,
    description: 'markdownStyle.linkVariants["^notion:"].backgroundColor',
  },
};
