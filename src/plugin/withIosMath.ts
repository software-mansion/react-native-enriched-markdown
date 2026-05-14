import configPlugins, { type ConfigPlugin } from '@expo/config-plugins';
import fs from 'fs';
import path from 'path';

const { withDangerousMod } = configPlugins;

const ENABLE_ENV = "ENV['ENRICHED_MARKDOWN_ENABLE_MATH']";
const ENGINE_ENV = "ENV['ENRICHED_MARKDOWN_MATH_ENGINE']";

export const withIosMath: ConfigPlugin<{
  enableMath?: boolean;
  mathEngine?: 'iosmath' | 'ratex';
}> = (config, { enableMath = true, mathEngine = 'iosmath' } = {}) => {
  // Nothing to write when math is enabled with the default engine — that's
  // already how the podspec behaves with no env overrides.
  if (enableMath && mathEngine === 'iosmath') {
    return config;
  }

  return withDangerousMod(config, [
    'ios',
    async (modConfig) => {
      const file = path.join(
        modConfig.modRequest.platformProjectRoot,
        'Podfile'
      );
      const contents = fs.readFileSync(file, 'utf8');

      // Strip any env lines this plugin previously wrote so re-runs stay
      // idempotent.
      const filteredLines = contents
        .split('\n')
        .filter(
          (line) =>
            !line.includes('ENRICHED_MARKDOWN_ENABLE_MATH') &&
            !line.includes('ENRICHED_MARKDOWN_MATH_ENGINE')
        );

      const prepend: string[] = [];
      if (!enableMath) {
        prepend.push(`${ENABLE_ENV} = '0'`);
      }
      if (enableMath && mathEngine !== 'iosmath') {
        prepend.push(`${ENGINE_ENV} = '${mathEngine}'`);
      }

      const out = [...prepend, ...filteredLines].join('\n');
      fs.writeFileSync(file, out);

      return modConfig;
    },
  ]);
};
