const path = require('path');
const { getDefaultConfig } = require('@react-native/metro-config');

const root = path.resolve(__dirname, '../..');
const rnMacosDir = path.dirname(
  require.resolve('react-native-macos/package.json', { paths: [__dirname] })
);
// Pin react to this workspace to avoid duplicate-instance dispatcher errors.
const reactMainPath = require.resolve('react', { paths: [__dirname] });

/** @type {import('metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

config.projectRoot = __dirname;
config.watchFolders = [root];

config.resolver = {
  ...config.resolver,
  platforms: [...(config.resolver.platforms || []), 'macos'],
  nodeModulesPaths: [path.join(__dirname, 'node_modules')],
};

// Redirect react-native → react-native-macos.
// Deep subpath imports (react-native/Libraries/…) resolve relative to the
// react-native-macos package root so Metro handles platform variants correctly.
const fakeOrigin = path.join(rnMacosDir, '_resolver_shim.js');

config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (moduleName === 'react') {
    return { filePath: reactMainPath, type: 'sourceFile' };
  }

  if (moduleName === 'react-native') {
    return context.resolveRequest(context, 'react-native-macos', platform);
  }

  if (moduleName.startsWith('react-native/')) {
    const subPath = './' + moduleName.slice('react-native/'.length);
    return context.resolveRequest(
      { ...context, originModulePath: fakeOrigin },
      subPath,
      platform
    );
  }

  return context.resolveRequest(context, moduleName, platform);
};

module.exports = config;
