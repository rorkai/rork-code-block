import SwiftUI

/// Arranges the source and controls presented by a code block.
///
/// A style receives the already configured source view and copy button. It can
/// place those views in any chrome without taking ownership of highlighting or
/// text layout.
@MainActor
public protocol CodeBlockStyle {
  /// Identifies the view returned by ``makeBody(configuration:)``.
  associatedtype Body: View

  /// Provides the source, language, and controls available to the style.
  typealias Configuration = CodeBlockStyleConfiguration

  /// Builds the complete presentation of a code block.
  ///
  /// - Parameter configuration: The source and controls to arrange.
  /// - Returns: The styled code block presentation.
  @ViewBuilder
  func makeBody(configuration: Configuration) -> Body

  /// Identifies a fixed light or dark background drawn by the style.
  ///
  /// Returning `nil` follows the surrounding SwiftUI color scheme. A style
  /// that always paints a dark or light card should report that appearance so
  /// syntax colors and scroll indicators stay legible.
  var codeAppearance: ColorScheme? { get }
}

extension CodeBlockStyle {
  /// Follows the surrounding SwiftUI color scheme by default.
  public var codeAppearance: ColorScheme? { nil }
}

/// Contains the source and controls arranged by a ``CodeBlockStyle``.
public struct CodeBlockStyleConfiguration {
  /// Presents the selectable and horizontally scrollable source text.
  public struct Content: View {
    /// Stores the type-erased source view supplied by ``CodeBlock``.
    private let content: AnyView

    /// Creates an opaque source view for a style configuration.
    ///
    /// - Parameter content: The configured source view.
    init(_ content: some View) {
      self.content = AnyView(content)
    }

    /// Returns the source view supplied by the code block.
    public var body: some View {
      content
    }
  }

  /// Presents the button that copies the complete source string.
  public struct CopyButton: View {
    /// Stores the type-erased button supplied by ``CodeBlock``.
    private let content: AnyView

    /// Creates an opaque copy button for a style configuration.
    ///
    /// - Parameter content: The configured copy button.
    init(_ content: some View) {
      self.content = AnyView(content)
    }

    /// Returns the copy button supplied by the code block.
    public var body: some View {
      content
    }
  }

  /// Holds the normalized language identifier used for highlighting.
  public let language: CodeLanguage

  /// Holds the human-readable language label presented by the style.
  public let languageName: String

  /// Holds the complete source text represented by the code block.
  public let source: String

  /// Holds the configured selectable source view.
  public let content: Content

  /// Holds the configured source-copying control.
  public let copyButton: CopyButton
}

/// Erases a concrete code block style for storage in the SwiftUI environment.
@MainActor
struct AnyCodeBlockStyle: CodeBlockStyle {
  /// Stores the fixed appearance reported by the wrapped style.
  let codeAppearance: ColorScheme?

  /// Stores the wrapped style's body builder.
  private let makeBodyClosure: @MainActor (Configuration) -> AnyView

  /// Creates a type-erased wrapper around a concrete style.
  ///
  /// - Parameter style: The style whose behavior should be forwarded.
  init(_ style: some CodeBlockStyle) {
    codeAppearance = style.codeAppearance
    makeBodyClosure = { configuration in
      AnyView(style.makeBody(configuration: configuration))
    }
  }

  /// Forwards body construction to the wrapped style.
  ///
  /// - Parameter configuration: The source and controls to arrange.
  /// - Returns: The type-erased styled presentation.
  func makeBody(configuration: Configuration) -> AnyView {
    makeBodyClosure(configuration)
  }
}

extension CodeBlockStyle where Self == DefaultCodeBlockStyle {
  /// Returns the adaptive bordered card style.
  public static var `default`: Self { Self() }
}

extension CodeBlockStyle where Self == TerminalCodeBlockStyle {
  /// Returns the dark terminal-inspired card style.
  public static var terminal: Self { Self() }
}
