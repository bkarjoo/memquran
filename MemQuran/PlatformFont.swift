import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformFont = NSFont
#else
import UIKit
typealias PlatformFont = UIFont
#endif

/// Cross-platform font utilities
struct FontUtilities {
    /// Get a font by name and size, with fallback to system font
    static func font(named name: String, size: CGFloat) -> PlatformFont {
        #if os(macOS)
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
        #else
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
        #endif
    }

    /// Calculate the size of a string with given font
    static func size(of text: String, font: PlatformFont) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attributes)
    }

    /// Get available font families (for settings)
    static func availableFontFamilies() -> [String] {
        #if os(macOS)
        return NSFontManager.shared.availableFontFamilies
        #else
        return UIFont.familyNames
        #endif
    }
}
