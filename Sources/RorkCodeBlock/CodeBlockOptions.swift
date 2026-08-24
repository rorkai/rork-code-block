import UIKit

/// Controls when a code block colors syntax captures.
public enum CodeSyntaxHighlighting: Hashable, Sendable {
  /// Applies each exact parser result as it becomes available.
  ///
  /// This mode suits complete source and ordinary edits. Apps that append
  /// streamed source should provide their streaming state through
  /// ``incremental(whileStreaming:)`` or ``deferred(whileStreaming:)``.
  /// An unavailable language falls back to unstyled source.
  case automatic

  /// Highlights the settled part of streamed source while the uncertain
  /// tail stays neutral.
  ///
  /// While streaming, every revision is parsed incrementally and Rork
  /// Highlighter reports how much of it no longer depends on unseen input.
  /// Settled source shows its exact syntax colors immediately. The trailing
  /// region that Tree-sitter still classifies through error recovery starts
  /// in the theme's base color, and each classification there appears once
  /// it has outlived a fixed amount of appended source, so multiline
  /// constructs color while they stream without exposing recovery guesses,
  /// regardless of chunk size. Source that was revealed and then drawn
  /// back into recovery keeps its last colors instead of flickering.
  /// Changing `whileStreaming` to `false` reconciles the complete source
  /// with a fresh parse, which matches one-shot highlighting exactly.
  ///
  /// - Parameter whileStreaming: Whether the source is still receiving updates.
  case incremental(whileStreaming: Bool)

  /// Presents plain source while streaming and highlights it when streaming
  /// finishes.
  ///
  /// - Parameter whileStreaming: Whether the source is still receiving updates.
  case deferred(whileStreaming: Bool)

  /// Draws the complete source with the configured text color.
  case disabled

  /// Returns whether the current source revision should be highlighted.
  var highlightsCurrentSource: Bool {
    switch self {
    case .automatic, .incremental:
      true
    case .deferred(let whileStreaming):
      !whileStreaming
    case .disabled:
      false
    }
  }

  /// Returns whether provisional syntax colors should remain stable.
  var preservesProvisionalColors: Bool {
    self == .incremental(whileStreaming: true)
  }

  /// Returns whether the source is still receiving streamed updates.
  var isActivelyStreaming: Bool {
    switch self {
    case .incremental(let whileStreaming), .deferred(let whileStreaming):
      whileStreaming
    case .automatic, .disabled:
      false
    }
  }

  /// Returns whether inserted source should use the syntax theme baseline.
  var usesSyntaxThemeBaseline: Bool {
    switch self {
    case .automatic, .incremental:
      true
    case .deferred, .disabled:
      false
    }
  }

  /// Returns whether two values can reuse the same visible TextKit contents.
  ///
  /// The active flag changes processing behavior without changing the font,
  /// theme, or base attributes already visible in the text storage.
  ///
  /// - Parameter other: The highlighting behavior to compare.
  /// - Returns: `true` when changing the value does not require a plain reset.
  func hasCompatiblePresentation(with other: Self) -> Bool {
    switch (self, other) {
    case (.incremental, .incremental), (.deferred, .deferred):
      true
    default:
      self == other
    }
  }
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
