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

  # Math configuration.
  #
  # ENRICHED_MARKDOWN_ENABLE_MATH ('1' default, '0' to disable) toggles the
  # whole math subsystem on or off, same as before.
  #
  # ENRICHED_MARKDOWN_MATH_ENGINE ('iosmath' default, or 'ratex') selects the
  # rendering backend. iosMath covers the surface most apps need; RaTeX is a
  # KaTeX port with broader command coverage (\operatorname, \boxed, \dfrac,
  # mhchem, ...) and ships its own font bundle. Only the chosen engine's
  # source set is compiled, so the binary doesn't carry both.
  #
  # RaTeX targets iOS 14+ and has no macOS slice — when targeting macOS the
  # podspec stays on iosMath. See engines/ratex/ENRMRaTeXMathEngine.swift.
  enable_math = ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] != '0'
  math_engine = (ENV['ENRICHED_MARKDOWN_MATH_ENGINE'] || 'iosmath').downcase

  unless ['iosmath', 'ratex'].include?(math_engine)
    raise "ENRICHED_MARKDOWN_MATH_ENGINE must be 'iosmath' or 'ratex' (got: #{math_engine.inspect})"
  end

  source_files = ["ios/**/*.{h,m,mm,cpp}", "cpp/md4c/*.{c,h}", "cpp/parser/*.{hpp,cpp}"]
  exclude_files = []
  preprocessor_defs = '$(inherited) MD4C_USE_UTF8=1'
  swift_active_conditions = ''

  if enable_math
    preprocessor_defs += ' ENRICHED_MARKDOWN_MATH=1'
    swift_active_conditions = 'ENRICHED_MARKDOWN_MATH'

    case math_engine
    when 'iosmath'
      preprocessor_defs += ' ENRICHED_MARKDOWN_MATH_ENGINE_IOSMATH=1'
      swift_active_conditions += ' ENRICHED_MARKDOWN_MATH_ENGINE_IOSMATH'
      s.dependency 'iosMath', '~> 0.9'
      exclude_files << 'ios/engines/ratex/**/*'
    when 'ratex'
      preprocessor_defs += ' ENRICHED_MARKDOWN_MATH_ENGINE_RATEX=1'
      swift_active_conditions += ' ENRICHED_MARKDOWN_MATH_ENGINE_RATEX'
      s.dependency 'ratex-react-native'
      source_files << 'ios/engines/ratex/*.swift'
      s.swift_version = '5.9'
      exclude_files << 'ios/engines/iosmath/**/*'
    end
  else
    exclude_files << 'ios/engines/**/*'
  end

  s.source_files = source_files
  s.private_header_files = "ios/**/*.h"
  s.exclude_files = exclude_files unless exclude_files.empty?

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/cpp/md4c" "$(PODS_TARGET_SRCROOT)/cpp/parser" "$(PODS_TARGET_SRCROOT)/ios/internals" "$(PODS_TARGET_SRCROOT)/ios/input/internals" "$(PODS_TARGET_SRCROOT)/ios/engines"',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_defs,
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => swift_active_conditions,
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17'
  }

  install_modules_dependencies(s)
end
