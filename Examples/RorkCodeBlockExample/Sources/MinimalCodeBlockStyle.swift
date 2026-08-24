import RorkCodeBlock
import SwiftUI

/// Presents a compact dark code card with understated chrome.
struct MinimalCodeBlockStyle: CodeBlockStyle {
  /// Keeps syntax colors and controls aligned with the fixed dark background.
  var codeAppearance: ColorScheme? { .dark }

  /// Arranges the language, copy button, and source inside one compact card.
  ///
  /// - Parameter configuration: The source and controls supplied by the block.
  /// - Returns: The complete minimal card presentation.
  func makeBody(configuration: Configuration) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: Metrics.headerSpacing) {
        Text(configuration.languageName)
          .font(.caption.weight(.semibold))

        Spacer()

        configuration.copyButton
      }
      .foregroundStyle(Palette.label)
      .padding(.horizontal, Metrics.horizontalPadding)
      .padding(.vertical, Metrics.headerPadding)

      Divider()
        .overlay(Palette.border)

      configuration.content
    }
    .background(Palette.background)
    .compositingGroup()
    .clipShape(.rect(cornerRadius: Metrics.cornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
        .stroke(Palette.border, lineWidth: Metrics.borderWidth)
    }
  }

  /// Stores the colors used by the minimal card.
  private enum Palette {
    /// Draws the card behind the highlighted source.
    static let background = Color(red: 0.07, green: 0.08, blue: 0.10)

    /// Draws the subtle edge and header separator.
    static let border = Color.white.opacity(0.10)

    /// Keeps the compact header quieter than the highlighted source.
    static let label = Color.white.opacity(0.62)
  }

  /// Stores the fixed measurements used by the minimal card.
  private enum Metrics {
    /// Rounds the card without exaggerating its silhouette.
    static let cornerRadius: CGFloat = 16

    /// Keeps the outline aligned to a single display point.
    static let borderWidth: CGFloat = 1

    /// Aligns the header with the source text below it.
    static let horizontalPadding: CGFloat = 16

    /// Gives the compact header enough vertical breathing room.
    static let headerPadding: CGFloat = 10

    /// Separates the language label from any future header content.
    static let headerSpacing: CGFloat = 12
  }
}
