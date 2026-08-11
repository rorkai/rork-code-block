import SwiftUI
import UIKit

extension EdgeInsets {
  /// Converts directional insets for source text that always reads left to right.
  var resolvedLeftToRight: UIEdgeInsets {
    UIEdgeInsets(top: top, left: leading, bottom: bottom, right: trailing)
  }
}

extension DynamicTypeSize {
  /// Returns the UIKit category corresponding to this SwiftUI size.
  var contentSizeCategory: UIContentSizeCategory {
    switch self {
    case .xSmall:
      .extraSmall
    case .small:
      .small
    case .medium:
      .medium
    case .large:
      .large
    case .xLarge:
      .extraLarge
    case .xxLarge:
      .extraExtraLarge
    case .xxxLarge:
      .extraExtraExtraLarge
    case .accessibility1:
      .accessibilityMedium
    case .accessibility2:
      .accessibilityLarge
    case .accessibility3:
      .accessibilityExtraLarge
    case .accessibility4:
      .accessibilityExtraExtraLarge
    case .accessibility5:
      .accessibilityExtraExtraExtraLarge
    @unknown default:
      .large
    }
  }
}
