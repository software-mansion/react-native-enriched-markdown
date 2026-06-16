const path = require('path');
const pkg = require('../../packages/react-native-enriched-markdown/package.json');

module.exports = {
  reactNativePath: path.dirname(
    require.resolve('react-native-macos/package.json')
  ),
  project: {
    macos: {
      automaticPodsInstallation: true,
    },
  },
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
        macos: {},
      },
    },
  },
};
