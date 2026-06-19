const { withStorybook } = require('@storybook/react-native/withStorybook');

const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const { withMetroConfig } = require('react-native-monorepo-config');

const root = path.resolve(__dirname, '../..');
const defaultConfig = getDefaultConfig(__dirname);
const { assetExts, sourceExts } = defaultConfig.resolver;

module.exports = withStorybook(
  withMetroConfig(
    mergeConfig(defaultConfig, {
      transformer: {
        babelTransformerPath: require.resolve('react-native-svg-transformer'),
        unstable_allowRequireContext: true,
      },
      resolver: {
        assetExts: assetExts.filter((ext) => ext !== 'svg'),
        sourceExts: [...sourceExts, 'svg'],
      },
    }),
    { root, dirname: __dirname }
  )
);
