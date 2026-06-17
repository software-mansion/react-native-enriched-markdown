import { withGradleProperties, type ConfigPlugin } from '@expo/config-plugins';

export const withAndroidMath: ConfigPlugin<{ enableMath?: boolean }> = (
  config,
  { enableMath = true }
) => {
  if (enableMath) {
    return config;
  }
  return withGradleProperties(config, (gradleConfig) => {
    gradleConfig.modResults = gradleConfig.modResults.filter(
      (prop) =>
        prop.type !== 'property' || prop.key !== 'enrichedMarkdown.enableMath'
    );

    gradleConfig.modResults.push({
      type: 'property',
      key: 'enrichedMarkdown.enableMath',
      value: 'false',
    });

    return gradleConfig;
  });
};
