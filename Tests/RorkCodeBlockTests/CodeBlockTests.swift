import RorkCodeBlock
import Testing

/// Verifies the public code block construction API without testable imports.
@MainActor
@Suite("Code block API")
struct CodeBlockTests {
  /// Verifies that the primary initializer accepts bundled language members.
  @Test("Creates a typed code block")
  func createsTypedCodeBlock() {
    let block = CodeBlock("let value = 42", language: .swift)

    #expect(block.source == "let value = 42")
    #expect(block.language == .swift)
    #expect(block.languageName == "Swift")
  }

  /// Verifies that a string alias keeps its caller-provided display spelling.
  @Test("Creates a code block from an alias")
  func createsCodeBlockFromAlias() {
    let block = CodeBlock("const value = 42", language: "JavaScript")

    #expect(block.language == .javascript)
    #expect(block.languageName == "JavaScript")
  }

  /// Verifies that typed language labels preserve familiar technical spelling.
  @Test("Formats bundled language names")
  func formatsBundledLanguageNames() {
    #expect(CodeBlock("", language: .cpp).languageName == "C++")
    #expect(CodeBlock("", language: .graphql).languageName == "GraphQL")
    #expect(CodeBlock("", language: .objectiveC).languageName == "Objective-C")
    #expect(CodeBlock("", language: .typescript).languageName == "TypeScript")
    #expect(
      CodeBlock("", language: CodeLanguage("custom-language")).languageName
        == "Custom Language"
    )
  }
}
