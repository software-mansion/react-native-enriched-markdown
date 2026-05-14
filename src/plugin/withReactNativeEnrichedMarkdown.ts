import { type ConfigPlugin } from '@expo/config-plugins';
import { withIosMath } from './withIosMath';
import { withAndroidMath } from './withAndroidMath';

type Props = {
  /** Toggle the whole math subsystem. Default `true`. */
  enableMath?: boolean;
  /**
   * Math rendering backend.
   * - `'iosmath'` (default) — iosMath on iOS, AndroidMath on Android. Same
   *   coverage the library has shipped since math support was added.
   * - `'ratex'` — RaTeX, a KaTeX port with broader command coverage
   *   (`\operatorname`, `\boxed`, `\dfrac`, mhchem, ...). Requires the
   *   `ratex-react-native` peer package to be installed; on macOS the
   *   `'iosmath'` path is used regardless.
   */
  mathEngine?: 'iosmath' | 'ratex';
};

const withEnrichedMarkdown: ConfigPlugin<Props | void> = (config, props) => {
  const enableMath = props?.enableMath !== false;
  const mathEngine = props?.mathEngine ?? 'iosmath';

  config = withAndroidMath(config, { enableMath, mathEngine });
  config = withIosMath(config, { enableMath, mathEngine });

  return config;
};

export default withEnrichedMarkdown;
