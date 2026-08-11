import UIKit

/// Controls whether a code block colors syntax captures.
public enum CodeSyntaxHighlighting: Hashable, Sendable {
  /// Highlights recognized languages and falls back to unstyled source when
  /// the requested language is unavailable.
  case automatic

  /// Draws the complete source with the configured text color.
  case disabled
}

/// Controls how lines wider than a code block are presented.
public enum CodeLineWrapping: Hashable, Sendable {
  /// Keeps every source line intact and enables horizontal scrolling.
  case disabled

  /// Wraps long source lines at character boundaries.
  case enabled

  /// Returns the TextKit line-breaking behavior for this option.
  var lineBreakMode: NSLineBreakMode {
    switch self {
    case .disabled:
      .byClipping
    case .enabled:
      .byCharWrapping
    }
  }
}

/// Controls the brightness of a code block's horizontal scroll indicator.
public enum CodeScrollIndicatorStyle: Hashable, Sendable {
  /// Selects a light or dark indicator from the card's effective appearance.
  case automatic

  /// Draws a light indicator for dark backgrounds.
  case light

  /// Draws a dark indicator for light backgrounds.
  case dark

  /// Resolves this option to the corresponding UIKit indicator style.
  ///
  /// - Parameter appearance: The effective appearance of the code card.
  /// - Returns: The UIKit style that remains legible on that appearance.
  func uiStyle(for appearance: UIUserInterfaceStyle) -> UIScrollView.IndicatorStyle {
    switch self {
    case .automatic:
      appearance == .dark ? .white : .black
    case .light:
      .white
    case .dark:
      .black
    }
  }
}

/// Controls whether horizontal scrolling rubber-bands at its boundaries.
public enum CodeScrollBounce: Hashable, Sendable {
  /// Bounces when the source is wider than its viewport.
  case automatic

  /// Stops at the exact horizontal boundaries.
  case disabled

  /// Returns whether UIKit should permit horizontal bouncing.
  var isEnabled: Bool {
    switch self {
    case .automatic:
      true
    case .disabled:
      false
    }
  }
}
