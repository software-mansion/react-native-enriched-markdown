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

  s.private_header_files = "ios/**/*.h", "cpp/**/*.{h,hpp}"

  # To disable LaTeX math rendering (RaTeX, iOS only), add ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] = '0' to your Podfile.
  # When math is enabled, consumers must use `use_frameworks! :linkage => :dynamic` (required for SPM interop).
  enable_math = ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] != '0'

  s.source_files = "ios/**/*.{h,m,mm,cpp,swift}", "cpp/md4c/*.{c,h}", "cpp/parser/*.{hpp,cpp}"
  unless enable_math
    s.exclude_files = "ios/math/**/*.swift"
  end

  preprocessor_defs = '$(inherited) MD4C_USE_UTF8=1'
  if enable_math
    preprocessor_defs += ' ENRICHED_MARKDOWN_MATH=1'
    if defined?(:spm_dependency)
      spm_dependency(s,
        url: 'https://github.com/erweixin/RaTeX.git',
        requirement: {kind: 'upToNextMajorVersion', minimumVersion: '0.1.9'},
        products: ['RaTeX']
      )
    end
  end

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/cpp/md4c" "$(PODS_TARGET_SRCROOT)/cpp/parser" "$(PODS_TARGET_SRCROOT)/ios/internals" "$(PODS_TARGET_SRCROOT)/ios/input/internals"',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_defs,
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'DEFINES_MODULE' => 'YES'
  }

  if enable_math
    # React Native's spm_dependency generates a module.modulemap at
    # ${BUILT_PRODUCTS_DIR}/include/ that re-declares RaTeXFFI, but the RaTeX
    # XCFramework already ships its own definition. Strip the duplicate to
    # prevent "redefinition of module 'RaTeXFFI'" during compilation.
    s.script_phases = [
      {
        name: 'Fix RaTeXFFI Module Redefinition',
        script: <<~'SCRIPT',
          # The shared module.modulemap lives in the platform build-products dir,
          # one level above the per-target BUILT_PRODUCTS_DIR that CocoaPods sets.
          MODULEMAP="${BUILT_PRODUCTS_DIR}/../include/module.modulemap"
          [ -f "$MODULEMAP" ] || exit 0
          sed -i '' -E '/^(framework )?module RaTeXFFI /,/^\}/d' "$MODULEMAP"
        SCRIPT
        execution_position: :before_compile
      }
    ]
  end

  install_modules_dependencies(s)
end
