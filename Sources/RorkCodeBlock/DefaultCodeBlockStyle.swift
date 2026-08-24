import SwiftUI

/// Presents source beneath a compact header inside an adaptive bordered card.
public struct DefaultCodeBlockStyle: CodeBlockStyle {
  /// Creates the default adaptive code block style.
  public init() {}

  /// Builds the bordered card around the configured source.
  ///
  /// - Parameter configuration: The source and controls to arrange.
  /// - Returns: The complete default card.
  public func makeBody(configuration: Configuration) -> some View {
    Card(configuration: configuration)
  }

  /// Draws the environment-driven default card.
  private struct Card: View {
    /// Holds the source and controls arranged by the card.
    let configuration: Configuration

    /// Reads the radius selected by the enclosing view hierarchy.
    @Environment(\.codeBlockCornerRadius) private var cornerRadius

    /// Reads the source insets used to align the header.
    @Environment(\.codeBlockContentInsets) private var contentInsets

    /// Reads the adaptive fill selected by the enclosing hierarchy.
    @Environment(\.codeBlockBackgroundStyle) private var backgroundStyle

    /// Reads the adaptive border selected by the enclosing hierarchy.
    @Environment(\.codeBlockBorderStyle) private var borderStyle

    /// Reads the foreground style applied to labels and controls.
    @Environment(\.codeBlockLabelStyle) private var labelStyle

    /// Returns the source and header inside the configured card chrome.
    var body: some View {
      VStack(spacing: 0) {
        Header(configuration: configuration, contentInsets: contentInsets)

        configuration.content
      }
      .background {
        shape.fill(backgroundStyle)
      }
      .clipShape(shape)
      .overlay {
        shape.stroke(borderStyle, lineWidth: Metrics.borderWidth)
      }
      .foregroundStyle(labelStyle)
    }

    /// Returns the continuous shape shared by the fill, clip, and border.
    private var shape: RoundedRectangle {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
  }

  /// Arranges the language label and copy button above the source.
  private struct Header: View {
    /// Holds the source metadata and copy button.
    let configuration: Configuration

    /// Holds the directional insets shared with the source text.
    let contentInsets: EdgeInsets

    /// Returns the compact header row.
    var body: some View {
      HStack {
        Text(configuration.languageName)
          .font(.subheadline.weight(.medium))

        Spacer()

        configuration.copyButton
      }
      .padding(.leading, contentInsets.leading)
      .padding(.trailing, contentInsets.trailing)
      .padding(.top, Metrics.headerTopPadding)
      .padding(.bottom, Metrics.headerBottomPadding)
    }
  }

  /// Stores the fixed measurements used by the default card.
  private enum Metrics {
    /// Keeps the border aligned to a single display point.
    static let borderWidth: CGFloat = 1

    /// Gives the header comfortable space above its controls.
    static let headerTopPadding: CGFloat = 12

    /// Keeps the header visually connected to the source below it.
    static let headerBottomPadding: CGFloat = 2
  }
}
