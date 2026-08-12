import RorkHighlighter
import SwiftUI
import Testing
import UIKit

@testable import RorkCodeBlock

/// Verifies the complete streaming path from source values into TextKit storage.
@MainActor
@Suite("Code text view", .serialized)
struct CodeTextViewTests {
  #if compiler(>=6.2)
    /// Verifies that iOS 26 cannot derive extra scroll padding from card corners.
    @Test("Keeps scroll padding independent of card corners")
    func keepsScrollPaddingIndependentOfCardCorners() {
      guard #available(iOS 26.0, visionOS 26.0, *) else {
        return
      }

      let textView = SelectableCodeTextView()

      #expect(
        textView.cornerConfiguration == .uniformCorners(radius: 0)
      )
    }
  #endif

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

  /// Verifies that a paused append stream receives one exact complete render.
  @Test("Reconciles exact styles after streaming settles")
  func reconcilesExactStylesAfterStreamingSettles() async throws {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let initialSource = #"""
      import SwiftUI

      struct Greeting: View {
      """#
    let finalSource =
      initialSource + #"""

            var body: some View {
                Text("Hello")
            }
        }
        """#

    coordinator.enqueue(rendition(source: initialSource), in: textView)
    try await waitUntil {
      !coordinator.isProcessingHighlights
    }

    let finalRendition = rendition(source: finalSource)
    coordinator.enqueue(finalRendition, in: textView)
    try await waitUntil {
      !coordinator.isProcessingHighlights
    }

    let snapshot = try Highlighter().highlight(finalSource, as: .swift)
    let referenceStorage = NSTextStorage(
      attributedString: finalRendition.attributedSource(finalSource)
    )
    let referenceRenderer = TextKitHighlightRenderer(
      theme: finalRendition.syntaxTheme,
      font: finalRendition.font
    )
    try referenceRenderer.render(snapshot, in: referenceStorage)

    #expect(
      allForegroundColors(in: textView.textStorage)
        == allForegroundColors(in: referenceStorage)
    )
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

  /// Verifies that wrapped source avoids unnecessary horizontal measurement.
  @Test("Skips horizontal measurement for wrapped source")
  func skipsHorizontalMeasurementForWrappedSource() {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()

    coordinator.enqueue(
      rendition(
        source: "let aVeryLongIdentifier = 42",
        syntaxHighlighting: .disabled,
        lineWrapping: .enabled
      ),
      in: textView
    )

    #expect(textView.widestLineWidth == 1)
    coordinator.cancel()
  }

  /// Verifies that an unavailable grammar leaves complete plain source visible.
  @Test("Falls back to plain source for an unknown language")
  func fallsBackToPlainSourceForUnknownLanguage() async throws {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let source = "let value = 42"

    coordinator.enqueue(rendition(source: source), in: textView)

    try await waitUntil {
      let colors = foregroundColors(in: textView)
      return colors.first != nil
        && colors.last != nil
        && colors.first != colors.last
    }

    let unknownLanguageRendition = CodeRendition(
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

    coordinator.enqueue(unknownLanguageRendition, in: textView)
    #expect(textView.textStorage.string == source)

    textView.textStorage.addAttribute(
      .foregroundColor,
      value: UIColor.red,
      range: NSRange(location: 0, length: 1)
    )
    textView.textStorage.addAttribute(
      .foregroundColor,
      value: UIColor.blue,
      range: NSRange(location: source.utf16.count - 1, length: 1)
    )

    try await waitUntil {
      let colors = foregroundColors(in: textView)
      return !coordinator.isProcessingHighlights
        && colors.first != nil
        && colors.first == colors.last
    }

    let colors = foregroundColors(in: textView)
    #expect(colors.first == colors.last)
    coordinator.cancel()
  }

  /// Returns the foreground colors at the beginning and end of a text view.
  ///
  /// - Parameter textView: The view whose rendered colors should be inspected.
  /// - Returns: The optional colors applied to the first and final code units.
  private func foregroundColors(
    in textView: SelectableCodeTextView
  ) -> (first: UIColor?, last: UIColor?) {
    let firstColor =
      textView.textStorage.attribute(
        .foregroundColor,
        at: 0,
        effectiveRange: nil
      ) as? UIColor
    let lastColor =
      textView.textStorage.attribute(
        .foregroundColor,
        at: textView.textStorage.length - 1,
        effectiveRange: nil
      ) as? UIColor

    return (first: firstColor, last: lastColor)
  }

  /// Returns the foreground color at every UTF-16 offset in TextKit storage.
  ///
  /// - Parameter textStorage: The storage whose rendered colors are inspected.
  /// - Returns: Colors ordered by their corresponding UTF-16 offsets.
  private func allForegroundColors(
    in textStorage: NSTextStorage
  ) -> [UIColor?] {
    (0..<textStorage.length).map { offset in
      textStorage.attribute(
        .foregroundColor,
        at: offset,
        effectiveRange: nil
      ) as? UIColor
    }
  }

  /// Creates the stable appearance shared by text view tests.
  ///
  /// - Parameters:
  ///   - source: The complete source for the test revision.
  ///   - syntaxHighlighting: Whether the revision should receive syntax colors.
  ///   - lineWrapping: Whether long lines should wrap inside the viewport.
  /// - Returns: A dark Swift rendition suitable for TextKit rendering.
  private func rendition(
    source: String,
    syntaxHighlighting: CodeSyntaxHighlighting = .automatic,
    lineWrapping: CodeLineWrapping = .disabled
  ) -> CodeRendition {
    CodeRendition(
      source: source,
      language: .swift,
      fontSize: 15,
      lineSpacing: 2,
      lineWrapping: lineWrapping,
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
    static let timeout = Duration.seconds(30)

    /// Keeps the test responsive without busy-waiting on the main actor.
    static let pollingInterval = Duration.milliseconds(10)

  }
}
