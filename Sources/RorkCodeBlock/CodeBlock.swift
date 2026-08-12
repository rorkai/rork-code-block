import RorkHighlighter
import SwiftUI
import UIKit

/// Presents selectable and copyable source with streaming syntax highlighting.
///
/// The view accepts ordinary SwiftUI value updates. It coalesces rapid source
/// changes and incrementally reparses and restyles the affected syntax through
/// Rork Highlighter. Long lines scroll horizontally unless
/// `.codeLineWrapping(_:)` enables wrapping.
///
/// ```swift
/// CodeBlock(source, language: .swift)
///     .codeFontSize(14)
///     .codeBlockStyle(.terminal)
/// ```
///
/// Text always reads from left to right, while the surrounding style continues
/// to follow the interface layout direction.
public struct CodeBlock: View {
  /// Holds the complete source presented by the code block.
  public let source: String

  /// Holds the normalized language identifier used for highlighting.
  public let language: CodeLanguage

  /// Holds the human-readable language label presented by the style.
  public let languageName: String

  /// Reads the style inherited from the enclosing view hierarchy.
  @Environment(\.codeBlockStyle) private var inheritedStyle

  /// Reads the unscaled monospaced font size.
  @Environment(\.codeFontSize) private var unscaledFontSize

  /// Reads the extra space between source lines.
  @Environment(\.codeLineSpacing) private var lineSpacing

  /// Reads whether long source lines wrap.
  @Environment(\.codeLineWrapping) private var lineWrapping

  /// Reads the number of character advances represented by a tab.
  @Environment(\.codeTabWidth) private var tabWidth

  /// Reads the color used by unhighlighted source.
  @Environment(\.codeTextColor) private var textColor

  /// Reads when syntax captures should be colored.
  @Environment(\.codeSyntaxHighlighting) private var syntaxHighlighting

  /// Reads an explicit syntax theme when one was supplied.
  @Environment(\.codeSyntaxTheme) private var explicitSyntaxTheme

  /// Reads the surrounding SwiftUI appearance.
  @Environment(\.colorScheme) private var colorScheme

  /// Reads the directional insets around the source.
  @Environment(\.codeBlockContentInsets) private var contentInsets

  /// Reads the directional insets around the horizontal indicator.
  @Environment(\.codeBlockScrollIndicatorInsets) private var indicatorInsets

  /// Reads the requested horizontal indicator brightness.
  @Environment(\.codeBlockScrollIndicatorStyle) private var indicatorStyle

  /// Reads whether horizontal scrolling may rubber-band.
  @Environment(\.codeBlockScrollBounce) private var scrollBounce

  /// Reads Dynamic Type from the environment so local overrides remain effective.
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// Creates a code block with a typed language identifier.
  ///
  /// - Parameters:
  ///   - source: The complete source to present.
  ///   - language: The language used for syntax highlighting.
  ///   - languageName: An optional label presented by the style. Passing `nil`
  ///     derives a readable label from the language identifier.
  public init(
    _ source: String,
    language: CodeLanguage,
    languageName: String? = nil
  ) {
    self.source = source
    self.language = language
    self.languageName = languageName ?? Self.defaultLanguageName(for: language)
  }

  /// Creates a code block from a language name or alias.
  ///
  /// The original spelling becomes the visible label, while Rork Highlighter
  /// normalizes it for catalog lookup.
  ///
  /// - Parameters:
  ///   - source: The complete source to present.
  ///   - language: The language name or alias used for highlighting.
  public init(_ source: String, language: String) {
    self.init(
      source,
      language: CodeLanguage(language),
      languageName: language
    )
  }

  /// Returns the styled code block presentation.
  public var body: some View {
    let style = inheritedStyle ?? AnyCodeBlockStyle(.default)
    let effectiveColorScheme = style.codeAppearance ?? colorScheme

    style.makeBody(
      configuration: CodeBlockStyleConfiguration(
        language: language,
        languageName: languageName,
        source: source,
        content: .init(
          CodeTextView(
            source: source,
            language: language,
            fontSize: scaledFontSize,
            lineSpacing: lineSpacing,
            lineWrapping: lineWrapping,
            tabWidth: tabWidth,
            textColor: textColor.resolved(for: effectiveColorScheme),
            syntaxHighlighting: syntaxHighlighting,
            syntaxTheme: syntaxTheme(for: effectiveColorScheme),
            textInsets: contentInsets.resolvedLeftToRight,
            indicatorInsets: indicatorInsets.resolvedLeftToRight,
            indicatorStyle: indicatorStyle.uiStyle(
              for: effectiveColorScheme.userInterfaceStyle
            ),
            scrollBounce: scrollBounce
          )
        ),
        copyButton: .init(CodeCopyButton(source: source))
      )
    )
  }

  /// Returns the syntax theme matching the effective card appearance.
  ///
  /// - Parameter colorScheme: The appearance reported by the active style.
  /// - Returns: The explicit theme or Rork Highlighter's matching default.
  private func syntaxTheme(for colorScheme: ColorScheme) -> HighlightTheme {
    explicitSyntaxTheme ?? (colorScheme == .dark ? .rorkDark : .rorkLight)
  }

  /// Returns the font size after applying the current Dynamic Type category.
  private var scaledFontSize: CGFloat {
    UIFontMetrics(forTextStyle: .body).scaledValue(
      for: unscaledFontSize,
      compatibleWith: UITraitCollection(
        preferredContentSizeCategory: dynamicTypeSize.contentSizeCategory
      )
    )
  }

  /// Derives a readable label from a normalized language identifier.
  ///
  /// - Parameter language: The language whose label is needed.
  /// - Returns: A title-cased label suitable for the default style.
  nonisolated private static func defaultLanguageName(
    for language: CodeLanguage
  ) -> String {
    switch language.rawValue {
    case "c": "C"
    case "cpp": "C++"
    case "css": "CSS"
    case "graphql": "GraphQL"
    case "html": "HTML"
    case "javascript": "JavaScript"
    case "jsdoc": "JSDoc"
    case "json": "JSON"
    case "json5": "JSON5"
    case "markdown-inline": "Markdown Inline"
    case "mdx": "MDX"
    case "objective-c": "Objective-C"
    case "properties": "Java Properties"
    case "regex": "Regular Expression"
    case "scss": "SCSS"
    case "sql": "SQL"
    case "toml": "TOML"
    case "tsx": "TSX"
    case "typescript": "TypeScript"
    case "xml": "XML"
    case "yaml": "YAML"
    default:
      language.rawValue
        .split(separator: "-", omittingEmptySubsequences: false)
        .map { component in
          component.prefix(1).uppercased() + component.dropFirst()
        }
        .joined(separator: " ")
    }
  }
}

extension ColorScheme {
  /// Returns the UIKit appearance represented by this SwiftUI color scheme.
  var userInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    @unknown default:
      .light
    }
  }
}
