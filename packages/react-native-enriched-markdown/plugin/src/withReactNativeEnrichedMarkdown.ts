import { type ConfigPlugin } from '@expo/config-plugins';
import { withIosMath } from './withIosMath';
import { withAndroidMath } from './withAndroidMath';

const withEnrichedMarkdown: ConfigPlugin<{ enableMath?: boolean } | void> = (
  config,
  props
) => {
  const enableMath = props?.enableMath !== false;

  config = withAndroidMath(config, { enableMath });
  config = withIosMath(config, { enableMath });

  return config;
};

export default withEnrichedMarkdown;
