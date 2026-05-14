import configPlugins, { type ConfigPlugin } from '@expo/config-plugins';

const { withGradleProperties } = configPlugins;

const ENABLE_KEY = 'enrichedMarkdown.enableMath';
const ENGINE_KEY = 'enrichedMarkdown.mathEngine';

// User-facing engine name → gradle property value. We expose a single
// 'iosmath' name at the JS level so the plugin API stays symmetric across
// platforms; under the hood Android uses the AndroidMath Kotlin port.
type MathEngine = 'iosmath' | 'ratex';
const ENGINE_GRADLE_VALUE: Record<MathEngine, string> = {
  iosmath: 'androidmath',
  ratex: 'ratex',
};

export const withAndroidMath: ConfigPlugin<{
  enableMath?: boolean;
  mathEngine?: MathEngine;
}> = (config, props = {}) => {
  const enableMath = props.enableMath !== false;
  const mathEngine: MathEngine = props.mathEngine ?? 'iosmath';

  if (enableMath && mathEngine === 'iosmath') {
    return config;
  }

  return withGradleProperties(config, (gradleConfig) => {
    gradleConfig.modResults = gradleConfig.modResults.filter(
      (prop) =>
        prop.type !== 'property' ||
        (prop.key !== ENABLE_KEY && prop.key !== ENGINE_KEY)
    );

    if (!enableMath) {
      gradleConfig.modResults.push({
        type: 'property',
        key: ENABLE_KEY,
        value: 'false',
      });
    }

    if (enableMath) {
      gradleConfig.modResults.push({
        type: 'property',
        key: ENGINE_KEY,
        value: ENGINE_GRADLE_VALUE[mathEngine],
      });
    }

    return gradleConfig;
  });
};
