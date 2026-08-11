import SwiftUI

/// Presents source in a dark terminal-inspired card with window controls.
public struct TerminalCodeBlockStyle: CodeBlockStyle {
  /// Reports the fixed dark card appearance to the source renderer.
  public var codeAppearance: ColorScheme? { .dark }

  /// Creates the terminal-inspired code block style.
  public init() {}

  /// Builds the terminal card around the configured source.
  ///
  /// - Parameter configuration: The source and controls to arrange.
  /// - Returns: The complete terminal card.
  public func makeBody(configuration: Configuration) -> some View {
    VStack(spacing: 0) {
      TrafficLights()

      configuration.content

      Footer(configuration: configuration)
    }
    .background(Metrics.background)
    .clipShape(.rect(cornerRadius: Metrics.cornerRadius, style: .continuous))
  }

  /// Presents decorative window controls above the source.
  private struct TrafficLights: View {
    /// Returns the three decorative terminal controls.
    var body: some View {
      HStack(spacing: Metrics.trafficLightSpacing) {
        ForEach(Metrics.trafficLightColors, id: \.self) { color in
          Circle()
            .fill(color)
            .frame(
              width: Metrics.trafficLightDiameter,
              height: Metrics.trafficLightDiameter
            )
        }

        Spacer()
      }
      .padding(.horizontal, Metrics.horizontalPadding)
      .padding(.vertical, Metrics.trafficLightVerticalPadding)
      .accessibilityHidden(true)
    }
  }

  /// Presents the language and copy control below the source.
  private struct Footer: View {
    /// Holds the language label and copy button.
    let configuration: Configuration

    /// Returns the compact terminal footer.
    var body: some View {
      HStack {
        Text(configuration.languageName.uppercased())
          .font(.caption2.weight(.semibold))

        Spacer()

        configuration.copyButton
      }
      .foregroundStyle(Metrics.label)
      .padding(.horizontal, Metrics.horizontalPadding)
      .padding(.bottom, Metrics.footerBottomPadding)
    }
  }

  /// Stores the fixed visual values used by the terminal style.
  private enum Metrics {
    /// Draws the fixed terminal card background.
    static let background = Color(red: 0.11, green: 0.12, blue: 0.15)

    /// Keeps the terminal chrome behind the brighter source text.
    static let label = Color.white.opacity(0.55)

    /// Rounds the terminal card without exaggerating its silhouette.
    static let cornerRadius: CGFloat = 12

    /// Aligns the decorative chrome with the source text.
    static let horizontalPadding: CGFloat = 14

    /// Matches the familiar scale of macOS window controls.
    static let trafficLightDiameter: CGFloat = 10

    /// Keeps the three decorative controls visually grouped.
    static let trafficLightSpacing: CGFloat = 6

    /// Centers the decorative controls inside the terminal header.
    static let trafficLightVerticalPadding: CGFloat = 10

    /// Leaves a small breathing space below the footer controls.
    static let footerBottomPadding: CGFloat = 6

    /// Provides the familiar red, yellow, and green window sequence.
    static let trafficLightColors: [Color] = [.red, .yellow, .green]
  }
}
