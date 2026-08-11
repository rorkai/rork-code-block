import RorkHighlighter
import SwiftUI
import Testing
import UIKit

@testable import RorkCodeBlock

/// Verifies the complete streaming path from source values into TextKit storage.
@MainActor
@Suite("Code text view")
struct CodeTextViewTests {
  /// Verifies that rapid source updates converge on highlighted final storage.
  @Test("Renders coalesced streaming source")
  func rendersCoalescedStreamingSource() async throws {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let revisions = [
      "let",
      "let ",
      "let greeting",
      "let greeting = ",
      "let greeting = \"Hello",
      "let greeting = \"Hello, Rork!\"",
    ]

    for revision in revisions {
      coordinator.enqueue(rendition(source: revision), in: textView)
    }

    #expect(textView.textStorage.string == revisions.last)

    try await waitUntil {
      let keywordColor =
        textView.textStorage.attribute(
          .foregroundColor,
          at: 0,
          effectiveRange: nil
        ) as? UIColor
      let identifierColor =
        textView.textStorage.attribute(
          .foregroundColor,
          at: 4,
          effectiveRange: nil
        ) as? UIColor

      return keywordColor != nil
        && identifierColor != nil
        && keywordColor != identifierColor
    }

    #expect(textView.textStorage.string == revisions.last)
    #expect(textView.textStorage.attribute(.font, at: 0, effectiveRange: nil) != nil)
    #expect(
      textView.textStorage.attribute(
        .paragraphStyle,
        at: 0,
        effectiveRange: nil
      ) != nil
    )

    let keywordColor =
      textView.textStorage.attribute(
        .foregroundColor,
        at: 0,
        effectiveRange: nil
      ) as? UIColor
    let identifierColor =
      textView.textStorage.attribute(
        .foregroundColor,
        at: 4,
        effectiveRange: nil
      ) as? UIColor

    #expect(keywordColor != nil)
    #expect(identifierColor != nil)
    #expect(keywordColor != identifierColor)

    coordinator.cancel()
  }

  /// Verifies that disabling highlighting presents the latest source immediately.
  @Test("Renders plain source when highlighting is disabled")
  func rendersPlainSourceWhenHighlightingIsDisabled() {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let source = "let value = 42"

    coordinator.enqueue(
      rendition(
        source: source,
        syntaxHighlighting: .disabled
      ),
      in: textView
    )

    #expect(textView.textStorage.string == source)

    let firstColor =
      textView.textStorage.attribute(
        .foregroundColor,
        at: 0,
        effectiveRange: nil
      ) as? UIColor
    let finalColor =
      textView.textStorage.attribute(
        .foregroundColor,
        at: source.utf16.count - 1,
        effectiveRange: nil
      ) as? UIColor

    #expect(firstColor == finalColor)
    coordinator.cancel()
  }

  /// Verifies that an unavailable grammar leaves complete plain source visible.
  @Test("Falls back to plain source for an unknown language")
  func fallsBackToPlainSourceForUnknownLanguage() async throws {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let source = "unrecognized source"
    let rendition = CodeRendition(
      source: source,
      language: "not-a-language",
      fontSize: 15,
      lineSpacing: 2,
      lineWrapping: .disabled,
      tabWidth: 4,
      textColor: .white,
      syntaxHighlighting: .automatic,
      syntaxTheme: .rorkDark
    )

    coordinator.enqueue(rendition, in: textView)
    #expect(textView.textStorage.string == source)

    try await Task.sleep(for: TestMetrics.fallbackInterval)

    let firstColor =
      textView.textStorage.attribute(
        .foregroundColor,
        at: 0,
        effectiveRange: nil
      ) as? UIColor
    let finalColor =
      textView.textStorage.attribute(
        .foregroundColor,
        at: source.utf16.count - 1,
        effectiveRange: nil
      ) as? UIColor

    #expect(firstColor == finalColor)
    coordinator.cancel()
  }

  /// Creates the stable appearance shared by text view tests.
  ///
  /// - Parameters:
  ///   - source: The complete source for the test revision.
  ///   - syntaxHighlighting: Whether the revision should receive syntax colors.
  /// - Returns: A dark Swift rendition suitable for TextKit rendering.
  private func rendition(
    source: String,
    syntaxHighlighting: CodeSyntaxHighlighting = .automatic
  ) -> CodeRendition {
    CodeRendition(
      source: source,
      language: .swift,
      fontSize: 15,
      lineSpacing: 2,
      lineWrapping: .disabled,
      tabWidth: 4,
      textColor: .white,
      syntaxHighlighting: syntaxHighlighting,
      syntaxTheme: .rorkDark
    )
  }

  /// Waits for an asynchronous TextKit condition without blocking the main actor.
  ///
  /// - Parameter condition: The condition that completes the wait.
  /// - Throws: `CancellationError` when the test task is cancelled.
  private func waitUntil(
    _ condition: @MainActor () -> Bool
  ) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + TestMetrics.timeout

    while !condition() {
      guard clock.now < deadline else {
        Issue.record("Timed out waiting for the rendered source")
        return
      }

      try await Task.sleep(for: TestMetrics.pollingInterval)
    }
  }

  /// Stores the timing values used by asynchronous view tests.
  private enum TestMetrics {
    /// Allows parser initialization on a cold simulator without flakiness.
    static let timeout = Duration.seconds(5)

    /// Keeps the test responsive without busy-waiting on the main actor.
    static let pollingInterval = Duration.milliseconds(10)

    /// Allows the unknown-language fallback to complete after coalescing.
    static let fallbackInterval = Duration.milliseconds(100)
  }
}
