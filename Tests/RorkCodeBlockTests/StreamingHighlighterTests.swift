import RorkHighlighter
import Testing

@testable import RorkCodeBlock

/// Verifies that one code block reuses ordered Tree-sitter revisions.
@Suite("Streaming highlighter")
struct StreamingHighlighterTests {
  /// Verifies that an appended token advances the existing parse revision.
  @Test("Highlights an incremental append")
  func highlightsIncrementalAppend() async throws {
    let highlighter = StreamingHighlighter()
    let initialSource = "let greeting = "
    let finalSource = "let greeting = \"Hello\""

    let initial = try await highlighter.highlight(
      initialSource,
      as: .swift
    )
    let update = try await highlighter.highlight(
      finalSource,
      as: .swift
    )

    #expect(initial.snapshot.text == initialSource)
    #expect(initial.snapshot.revision == 0)
    #expect(update.snapshot.text == finalSource)
    #expect(update.snapshot.revision == 1)

    guard case .update(let previousSource, let edit, _) = update else {
      Issue.record("Expected an incremental update")
      return
    }

    #expect(previousSource == initialSource)
    #expect(edit.range == .init(location: initialSource.utf16.count, length: 0))
    #expect(edit.replacement == "\"Hello\"")
  }

  /// Verifies that changing the language opens a fresh parse session.
  @Test("Reopens the session for another language")
  func reopensSessionForAnotherLanguage() async throws {
    let highlighter = StreamingHighlighter()

    _ = try await highlighter.highlight(
      "let value = 42",
      as: .swift
    )
    let javascript = try await highlighter.highlight(
      "const value = 42",
      as: .javascript
    )

    #expect(javascript.snapshot.language == .javascript)
    #expect(javascript.snapshot.revision == 0)
  }

  /// Verifies that unsupported languages report their typed highlighting error.
  @Test("Reports an unknown language")
  func reportsUnknownLanguage() async {
    let highlighter = StreamingHighlighter()

    await #expect(throws: HighlighterError.self) {
      _ = try await highlighter.highlight(
        "plain source",
        as: "not-a-language"
      )
    }
  }
}
