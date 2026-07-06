import CoreText
import UIKit

enum FontHelpers {
    static func ensureBold(_ font: UIFont?) -> UIFont? {
        applyTrait(to: font, bold: true, italic: false)
    }

    static func ensureItalic(_ font: UIFont?) -> UIFont? {
        applyTrait(to: font, bold: false, italic: true)
    }

    static func cachedFont(from blockStyle: BlockStyle?) -> UIFont? {
        blockStyle?.font
    }

    static func ensureMonospaced(_ font: UIFont?, configFont: UIFont?) -> UIFont? {
        if let configFont {
            return configFont
        }
        guard let font else {
            return UIFont.monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                weight: .regular
            )
        }

        let weight: UIFont.Weight = hasBoldTrait(font) ? .bold : .regular
        return UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: weight)
    }

    private static func applyTrait(to font: UIFont?, bold: Bool, italic: Bool) -> UIFont? {
        guard let font else { return nil }

        let wantsBold = bold || hasBoldTrait(font)
        let wantsItalic = italic || hasItalicTrait(font)

        if wantsBold == hasBoldTrait(font), wantsItalic == hasItalicTrait(font) {
            return font
        }

        if let variant = resolveNamedVariant(from: font, bold: wantsBold, italic: wantsItalic) {
            return variant
        }

        if let synthesized = fontByAddingSymbolicTraits(to: font, bold: wantsBold, italic: wantsItalic) {
            return synthesized
        }

        // Custom font families often cannot synthesize traits. Preserve the newly requested style
        // by switching to the closest named face instead of leaving bold-only / upright text.
        if wantsItalic, !hasItalicTrait(font), wantsBold {
            if let italicFace = resolveNamedVariant(from: font, bold: false, italic: true) {
                return italicFace
            }
        }

        if wantsBold, !hasBoldTrait(font), !wantsItalic,
           let boldFace = resolveNamedVariant(from: font, bold: true, italic: false) {
            return boldFace
        }

        return font
    }

    private static func resolveNamedVariant(from font: UIFont, bold: Bool, italic: Bool) -> UIFont? {
        let family = fontFamilyPrefix(from: font.fontName)
        let size = font.pointSize

        for name in candidateFontNames(family: family, bold: bold, italic: italic) {
            if let variant = loadFont(named: name, size: size), matchesTraits(variant, bold: bold, italic: italic) {
                return variant
            }
        }

        return nil
    }

    private static func matchesTraits(_ font: UIFont, bold: Bool, italic: Bool) -> Bool {
        if bold, !hasBoldTrait(font) { return false }
        if italic, !hasItalicTrait(font) { return false }
        if !bold, hasBoldTrait(font) { return false }
        if !italic, hasItalicTrait(font) { return false }
        return true
    }

    private static func fontByAddingSymbolicTraits(to font: UIFont, bold: Bool, italic: Bool) -> UIFont? {
        var targetTraits = font.fontDescriptor.symbolicTraits
        if bold { targetTraits.insert(.traitBold) }
        if italic { targetTraits.insert(.traitItalic) }

        guard let descriptor = font.fontDescriptor.withSymbolicTraits(targetTraits) else {
            return nil
        }

        let synthesized = UIFont(descriptor: descriptor, size: font.pointSize)

        if bold, !hasBoldTrait(synthesized) { return nil }
        if italic, !hasItalicTrait(synthesized) { return nil }

        return synthesized
    }

    private static func loadFont(named name: String, size: CGFloat) -> UIFont? {
        ThemeResolver.loadCustomFont(named: name, size: size)
    }

    static func hasBoldTrait(_ font: UIFont) -> Bool {
        if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
            return true
        }
        return infersBoldStyle(from: font.fontName)
    }

    static func hasItalicTrait(_ font: UIFont) -> Bool {
        if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
            return true
        }
        return infersItalicStyle(from: font.fontName)
    }

    private static func infersBoldStyle(from name: String) -> Bool {
        let lower = name.lowercased()
        if lower.contains("bold") { return true }
        if lower.contains("semibold") || lower.contains("semi-bold") { return true }
        if lower.contains("heavy") || lower.contains("black") { return true }
        return false
    }

    private static func infersItalicStyle(from name: String) -> Bool {
        name.lowercased().contains("italic")
    }

    private static func fontFamilyPrefix(from fontName: String) -> String {
        let suffixes = [
            "-BoldItalic", "BoldItalic",
            "-SemiBold", "SemiBold", "-Semi-Bold",
            "-Bold", "Bold",
            "-Italic", "Italic",
            "-Medium", "Medium",
            "-Regular", "Regular",
            "-Light", "Light"
        ]

        for suffix in suffixes where fontName.hasSuffix(suffix) {
            return String(fontName.dropLast(suffix.count))
        }
        return fontName
    }

    private static func candidateFontNames(family: String, bold: Bool, italic: Bool) -> [String] {
        if bold, italic {
            return [
                "\(family)-BoldItalic",
                "\(family)BoldItalic",
                "\(family)-Bold-Italic"
            ]
        }
        if bold {
            return [
                "\(family)-Bold",
                "\(family)Bold",
                "\(family)-SemiBold",
                "\(family)SemiBold"
            ]
        }
        if italic {
            return [
                "\(family)-Italic",
                "\(family)Italic"
            ]
        }
        return [
            "\(family)-Regular",
            "\(family)Regular",
            family
        ]
    }
}
