require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "ReactNativeEnrichedMarkdown"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported, :osx => '14.0' }
  s.source       = { :git => "https://github.com/software-mansion-labs/react-native-enriched-markdown.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,cpp}", "cpp/md4c/*.{c,h}", "cpp/parser/*.{hpp,cpp}"
  s.private_header_files = "ios/**/*.h"

  # To disable LaTeX math rendering (iosMath, supported on iOS and macOS), add ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] = '0' to your Podfile.
  enable_math = ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] != '0'

  preprocessor_defs = '$(inherited) MD4C_USE_UTF8=1'
  if enable_math
    preprocessor_defs += ' ENRICHED_MARKDOWN_MATH=1'
     spm_dependency(s,
      url: 'https://github.com/kostub/iosMath.git',
      requirement: { kind: 'upToNextMajorVersion', minimumVersion: '2.2.0' },
      products: ['iosMath']
    )
  end

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/cpp/md4c" "$(PODS_TARGET_SRCROOT)/cpp/parser" "$(PODS_TARGET_SRCROOT)/ios/internals" "$(PODS_TARGET_SRCROOT)/ios/input/internals" "$(SYMROOT)/../../SourcePackages/checkouts/iosMath/iosMath/lib" "$(SYMROOT)/../../SourcePackages/checkouts/iosMath/iosMath/render" "$(SYMROOT)/../../SourcePackages/checkouts/iosMath/iosMath/render/internal"',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_defs,
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17'
  }

  install_modules_dependencies(s)
end
