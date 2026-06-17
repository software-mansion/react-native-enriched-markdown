const path = require('path');
const pkg = require('../../packages/react-native-enriched-markdown/package.json');

module.exports = {
  project: {
    ios: {
      automaticPodsInstallation: true,
    },
  },
  assets: ['./assets/fonts'],
  dependencies: {
    [pkg.name]: {
      root: path.join(
        __dirname,
        '../../packages/react-native-enriched-markdown'
      ),
      platforms: {
        // Codegen script incorrectly fails without this
        // So we explicitly specify the platforms with empty object
        ios: {},
        android: {},
      },
    },
  },
};
