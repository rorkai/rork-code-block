import RorkCodeBlock

/// Identifies one source fixture available in the example app.
enum ExampleLanguage: String, CaseIterable, Identifiable {
  /// Demonstrates a streaming SwiftUI code block.
  case swift = "Swift"

  /// Demonstrates a typed React component.
  case typescript = "TypeScript"

  /// Demonstrates Markdown with an injected Swift code fence.
  case markdown = "Markdown"

  /// Uses the enum value itself as stable picker identity.
  var id: Self { self }

  /// Returns the bundled language identifier for this fixture.
  var codeLanguage: CodeLanguage {
    switch self {
    case .swift:
      .swift
    case .typescript:
      .typescript
    case .markdown:
      .markdown
    }
  }

  /// Returns the complete source displayed by this fixture.
  var source: String {
    switch self {
    case .swift:
      #"""
      import RorkCodeBlock
      import SwiftUI

      struct StreamingReply: View {
          let chunks: AsyncStream<String>
          @State private var source = ""

          var body: some View {
              CodeBlock(source, language: .swift)
                  .task {
                      for await chunk in chunks {
                          source += chunk
                      }
                  }
          }
      }
      """#
    case .typescript:
      #"""
      type CodeCardProps = {
        source: string
        language: "tsx" | "typescript"
      }

      export function CodeCard({ source, language }: CodeCardProps) {
        return (
          <article aria-label={`${language} source`}>
            <pre><code>{source}</code></pre>
          </article>
        )
      }
      """#
    case .markdown:
      #"""
      # Streaming code

      Update one ordinary SwiftUI value as chunks arrive. Rork Code Block
      reuses its Tree-sitter session and redraws only affected ranges.

      ```swift
      CodeBlock(source, language: .swift)
          .codeBlockStyle(.terminal)
      ```
      """#
    }
  }
}
