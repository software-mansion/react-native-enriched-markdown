import { Appearance } from 'react-native';
import type { Preview } from '@storybook/react-native';

Appearance.setColorScheme('light');

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/,
      },
    },
  },
};

export default preview;
