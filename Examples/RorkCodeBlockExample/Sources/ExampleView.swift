import RorkCodeBlock
import SwiftUI

/// Presents the interactive language, style, and streaming showcase.
struct ExampleView: View {
  /// Owns the source revision and active replay operation.
  @State private var model = StreamingExampleModel(
    source: ExampleLanguage.swift.source
  )

  /// Holds the fixture selected by the language control.
  @State private var selectedLanguage = ExampleLanguage.swift

  /// Holds the card presentation selected by the style control.
  @State private var selectedPresentation = ExamplePresentation.adaptive

  /// Returns the complete interactive example screen.
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
          ExampleIntroduction()

          ExampleControls(
            selectedLanguage: $selectedLanguage,
            selectedPresentation: $selectedPresentation,
            isStreaming: model.isStreaming,
            replay: replay
          )

          ExampleCodePreview(
            source: model.source,
            language: selectedLanguage.codeLanguage,
            presentation: selectedPresentation
          )

          Text(
            "Select and copy the source just like ordinary text. Tap Replay to "
              + "watch incremental highlighting keep up with a rapid stream."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
        .frame(maxWidth: Metrics.contentWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, Metrics.horizontalPadding)
        .padding(.vertical, Metrics.verticalPadding)
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .navigationTitle("Rork Code Block")
      .navigationBarTitleDisplayMode(.inline)
      .onChange(of: selectedLanguage) { _, language in
        model.present(language.source)
      }
    }
  }

  /// Starts a new replay for the selected language fixture.
  private func replay() {
    model.replay(selectedLanguage.source)
  }

  /// Stores layout values shared by the example screen.
  private enum Metrics {
    /// Keeps the showcase readable on wide windows.
    static let contentWidth: CGFloat = 860

    /// Separates the screen's major content sections.
    static let sectionSpacing: CGFloat = 24

    /// Preserves comfortable margins on compact screens.
    static let horizontalPadding: CGFloat = 20

    /// Separates the showcase from the navigation chrome.
    static let verticalPadding: CGFloat = 24
  }
}

/// Introduces the purpose of the interactive example.
private struct ExampleIntroduction: View {
  /// Returns the title and concise package description.
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Native code blocks that keep up")
        .font(.largeTitle.bold())

      Text(
        "Selectable, copyable, Tree-sitter highlighted code for complete "
          + "snippets and streaming responses."
      )
      .font(.title3)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Presents the language, card style, and replay controls.
private struct ExampleControls: View {
  /// Updates the source fixture selected by the user.
  @Binding var selectedLanguage: ExampleLanguage

  /// Updates the code card presentation selected by the user.
  @Binding var selectedPresentation: ExamplePresentation

  /// Reports whether a replay is actively emitting source.
  let isStreaming: Bool

  /// Restarts the selected source fixture from an empty revision.
  let replay: () -> Void

  /// Returns the controls inside one adaptive material card.
  var body: some View {
    VStack(spacing: 18) {
      Picker("Language", selection: $selectedLanguage) {
        ForEach(ExampleLanguage.allCases) { language in
          Text(language.rawValue)
        }
      }
      .pickerStyle(.segmented)

      Picker("Presentation", selection: $selectedPresentation) {
        ForEach(ExamplePresentation.allCases) { presentation in
          Text(presentation.rawValue)
        }
      }
      .pickerStyle(.segmented)

      HStack {
        Label(
          isStreaming ? "Streaming" : "Ready",
          systemImage: isStreaming ? "waveform" : "checkmark.circle.fill"
        )
        .font(.subheadline.weight(.medium))
        .foregroundStyle(isStreaming ? Color.accentColor : .secondary)
        .animation(.smooth, value: isStreaming)

        Spacer()

        Button(action: replay) {
          Label(
            isStreaming ? "Restart" : "Replay",
            systemImage: "arrow.clockwise"
          )
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(18)
    .background(.thinMaterial, in: .rect(cornerRadius: 18, style: .continuous))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Example controls")
  }
}

/// Applies the selected presentation to the active source fixture.
private struct ExampleCodePreview: View {
  /// Holds the complete source revision to render.
  let source: String

  /// Holds the language used for syntax highlighting.
  let language: CodeLanguage

  /// Holds the card presentation selected by the user.
  let presentation: ExamplePresentation

  /// Returns the code block with the selected card style.
  @ViewBuilder
  var body: some View {
    switch presentation {
    case .adaptive:
      configuredBlock
        .codeBlockStyle(.default)
    case .terminal:
      configuredBlock
        .codeBlockStyle(.terminal)
    case .minimal:
      configuredBlock
        .codeBlockStyle(MinimalCodeBlockStyle())
    }
  }

  /// Returns the code block configuration shared by every card style.
  private var configuredBlock: some View {
    CodeBlock(source, language: language)
      .codeFontSize(14)
      .codeLineSpacing(3)
  }
}

#Preview {
  ExampleView()
}
