//
//  ENRMRaTeXMathEngine.swift
//
//  RaTeX-backed implementation of `ENRMMathEngine`. Selected at build time
//  when the Podfile sets `ENV['ENRICHED_MARKDOWN_MATH_ENGINE'] = 'ratex'`.
//
//  RaTeX ships its Swift surface (RaTeXEngine, RaTeXRenderer, RaTeXFontLoader)
//  via the `ratex-react-native` CocoaPod. The pod also vendors the KaTeX font
//  bundle and the underlying Rust FFI as an XCFramework, so consumers don't
//  need to add anything beyond the `s.dependency` in the podspec.
//

#if ENRICHED_MARKDOWN_MATH && ENRICHED_MARKDOWN_MATH_ENGINE_RATEX

import Foundation
import UIKit
import CoreGraphics
import ratex_react_native

@objcMembers
public final class ENRMRaTeXLayout: NSObject {
  public let width: CGFloat
  public let ascent: CGFloat
  public let descent: CGFloat

  private let renderer: RaTeXRenderer

  fileprivate init(renderer: RaTeXRenderer) {
    self.renderer = renderer
    self.width = renderer.width
    self.ascent = renderer.height
    self.descent = renderer.depth
    super.init()
  }

  /// Matches the `ENRMLaidOutMath` contract: caller hands us a top-left
  /// flipped CTM. RaTeX's renderer already draws in that convention so we
  /// can delegate directly.
  public func draw(in context: CGContext) {
    renderer.draw(in: context)
  }
}

@objcMembers
public final class ENRMRaTeXMathEngine: NSObject {
  public static let shared = ENRMRaTeXMathEngine()

  private override init() {
    super.init()
    Self.registerFontsIfNeeded()
  }

  public func layout(
    latex: String,
    displayMode: Bool,
    fontSize: CGFloat,
    color: UIColor?
  ) -> ENRMRaTeXLayout? {
    guard !latex.isEmpty else { return nil }
    do {
      let displayList = try RaTeXEngine.shared.parse(
        latex,
        displayMode: displayMode,
        color: color ?? .black
      )
      return ENRMRaTeXLayout(renderer: RaTeXRenderer(displayList: displayList, fontSize: fontSize))
    } catch {
      return nil
    }
  }

  /// `RaTeXFontLoader.ensureLoaded()` searches `Bundle.main` only, but the
  /// CocoaPod packages the KaTeX TTFs inside `RaTeXFonts.bundle` next to the
  /// host app bundle. Hand that bundle over first; the loader is idempotent
  /// and thread-safe.
  private static func registerFontsIfNeeded() {
    if let bundleURL = Bundle.main.url(forResource: "RaTeXFonts", withExtension: "bundle"),
       let fontBundle = Bundle(url: bundleURL) {
      _ = RaTeXFontLoader.loadFromBundle(fontBundle)
    }
    _ = RaTeXFontLoader.ensureLoaded()
  }
}

#endif
