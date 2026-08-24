import SwiftUI
import UIKit

/// Supplies the adaptive colors used by the default code block style.
enum CodeBlockPalette {
  /// Draws a quiet card that remains distinct from its surrounding page.
  static let background = Color(light: 0xF7F7F8, dark: 0x1E1F20)

  /// Separates the card without turning its outline into a focal point.
  static let border = Color(light: 0xE4E4E7, dark: 0x323335)

  /// Keeps labels and controls visually behind the source text.
  static let label = Color(light: 0x6C6C70, dark: 0xB9B9BE)

  /// Avoids the halation that pure white can produce across long dark blocks.
  static let text = Color(light: 0x111114, dark: 0xF7F7F9)
}

extension Color {
  /// Resolves this color against a specific card appearance.
  ///
  /// - Parameter colorScheme: The appearance presented by the surrounding
  ///   code block style.
  /// - Returns: A fixed color suitable for TextKit rendering.
  func resolved(for colorScheme: ColorScheme) -> Color {
    let traits = UITraitCollection(
      userInterfaceStyle: colorScheme == .dark ? .dark : .light
    )

    return Color(uiColor: UIColor(self).resolvedColor(with: traits))
  }

  /// Creates a dynamic color from light and dark RGB values.
  ///
  /// - Parameters:
  ///   - light: The RGB value used in light appearances.
  ///   - dark: The RGB value used in dark appearances.
  fileprivate init(light: UInt32, dark: UInt32) {
    self.init(
      uiColor: UIColor { traits in
        UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
      }
    )
  }
}

extension UIColor {
  /// Creates an opaque color from a `0xRRGGBB` value.
  ///
  /// - Parameter rgb: The red, green, and blue components packed into an
  ///   unsigned integer.
  fileprivate convenience init(rgb: UInt32) {
    self.init(
      red: CGFloat((rgb >> 16) & 0xFF) / 255,
      green: CGFloat((rgb >> 8) & 0xFF) / 255,
      blue: CGFloat(rgb & 0xFF) / 255,
      alpha: 1
    )
  }
}
