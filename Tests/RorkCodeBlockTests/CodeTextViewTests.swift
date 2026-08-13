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
      guard textView.textStorage.length > 4 else {
        return false
      }

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

  /// Verifies that source appears before asynchronous highlighting completes.
  @Test("Presents streamed source immediately")
  func presentsStreamedSourceImmediately() {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let source = "import SwiftUI"

    coordinator.enqueue(rendition(source: source), in: textView)

    #expect(textView.textStorage.string == source)
    coordinator.cancel()
  }

  /// Verifies that new source starts with the syntax theme's neutral color.
  @Test("Presents streamed source with the theme baseline")
  func presentsStreamedSourceWithThemeBaseline() {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let source = "import SwiftUI"

    coordinator.enqueue(rendition(source: source), in: textView)

    let color =
      textView.textStorage.attribute(
        .foregroundColor,
        at: 0,
        effectiveRange: nil
      ) as? UIColor
    #expect(
      color
        == nativeColor(HighlightTheme.rorkDark.baseStyle.foregroundColor)
    )
    coordinator.cancel()
  }

  /// Verifies that established syntax colors do not change during a stream.
  @Test("Keeps streamed syntax colors stable")
  func keepsStreamedSyntaxColorsStable() async throws {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let baseColor = nativeColor(
      HighlightTheme.rorkDark.baseStyle.foregroundColor
    )
    var establishedColors: [Int: UIColor] = [:]

    for revision in streamedRevisions(of: swiftSource, chunkSize: 7) {
      coordinator.enqueue(
        rendition(
          source: revision,
          syntaxHighlighting: .incremental(whileStreaming: true)
        ),
        in: textView
      )
      #expect(textView.textStorage.string == revision)

      try await waitUntil { !coordinator.isProcessingHighlights }

      let colors = allForegroundColors(in: textView.textStorage)
      for (offset, color) in establishedColors {
        #expect(
          colors[offset] == color,
          "Color changed at UTF-16 offset \(offset)"
        )
      }
      for (offset, color) in colors.enumerated() where color != baseColor {
        if let color {
          establishedColors[offset] = color
        }
      }
    }

    #expect(!establishedColors.isEmpty)
    #expect(textView.textStorage.string == swiftSource)
    coordinator.cancel()
  }

  /// Verifies color stability when source outruns parser processing.
  @Test("Keeps rapid streamed syntax colors stable")
  func keepsRapidStreamedSyntaxColorsStable() async throws {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let baseColor = nativeColor(
      HighlightTheme.rorkDark.baseStyle.foregroundColor
    )
    var establishedColors: [Int: UIColor] = [:]

    coordinator.enqueue(
      rendition(
        source: swiftSource,
        syntaxHighlighting: .incremental(whileStreaming: true)
      ),
      in: textView
    )
    try await waitUntil { !coordinator.isProcessingHighlights }
    coordinator.enqueue(
      rendition(
        source: "",
        syntaxHighlighting: .incremental(whileStreaming: true)
      ),
      in: textView
    )

    for revision in streamedRevisions(of: swiftSource, chunkSize: 7) {
      coordinator.enqueue(
        rendition(
          source: revision,
          syntaxHighlighting: .incremental(whileStreaming: true)
        ),
        in: textView
      )
      #expect(textView.textStorage.string == revision)

      retainSyntaxColors(
        in: textView.textStorage,
        excluding: baseColor,
        establishedColors: &establishedColors
      )
      try await Task.sleep(for: TestMetrics.streamingInterval)
      expectEstablishedColors(
        establishedColors,
        in: textView.textStorage
      )
      retainSyntaxColors(
        in: textView.textStorage,
        excluding: baseColor,
        establishedColors: &establishedColors
      )
    }

    try await waitUntil { !coordinator.isProcessingHighlights }
    expectEstablishedColors(establishedColors, in: textView.textStorage)
    #expect(!establishedColors.isEmpty)
    #expect(textView.textStorage.string == swiftSource)
    coordinator.cancel()
  }

  /// Verifies that ending a stream replaces provisional colors with exact ones.
  @Test("Reconciles completed streaming colors exactly")
  func reconcilesCompletedStreamingColorsExactly() async throws {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()

    for revision in streamedRevisions(of: swiftSource, chunkSize: 7) {
      coordinator.enqueue(
        rendition(
          source: revision,
          syntaxHighlighting: .incremental(whileStreaming: true)
        ),
        in: textView
      )
      try await Task.sleep(for: TestMetrics.streamingInterval)
    }

    coordinator.enqueue(
      rendition(
        source: swiftSource,
        syntaxHighlighting: .incremental(whileStreaming: false)
      ),
      in: textView
    )

    #expect(textView.textStorage.string == swiftSource)
    try await waitUntil { !coordinator.isProcessingHighlights }
    try await expectExactHighlighting(
      in: textView.textStorage,
      source: swiftSource
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

  /// Verifies that deferred highlighting waits for the stream to finish.
  @Test("Highlights deferred source after streaming finishes")
  func highlightsDeferredSourceAfterStreamingFinishes() async throws {
    let textView = SelectableCodeTextView()
    let coordinator = CodeTextView.Coordinator()
    let revisions = ["let", "let value", "let value = 42"]

    for revision in revisions {
      coordinator.enqueue(
        rendition(
          source: revision,
          syntaxHighlighting: .deferred(whileStreaming: true)
        ),
        in: textView
      )
    }

    let streamingColors = foregroundColors(in: textView)
    #expect(textView.textStorage.string == revisions.last)
    #expect(streamingColors.first == streamingColors.last)
    #expect(!coordinator.isProcessingHighlights)

    coordinator.enqueue(
      rendition(
        source: revisions.last ?? "",
        syntaxHighlighting: .deferred(whileStreaming: false)
      ),
      in: textView
    )

    try await waitUntil {
      let colors = foregroundColors(in: textView)
      return colors.first != nil
        && colors.last != nil
        && colors.first != colors.last
    }

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
    guard textView.textStorage.length > 0 else {
      return (first: nil, last: nil)
    }

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

  /// Checks every syntax color established by an earlier stream revision.
  ///
  /// - Parameters:
  ///   - establishedColors: Syntax colors keyed by their UTF-16 offsets.
  ///   - textStorage: The storage containing the newest source revision.
  private func expectEstablishedColors(
    _ establishedColors: [Int: UIColor],
    in textStorage: NSTextStorage
  ) {
    let colors = allForegroundColors(in: textStorage)
    for (offset, color) in establishedColors {
      #expect(
        colors[offset] == color,
        "Color changed at UTF-16 offset \(offset)"
      )
    }
  }

  /// Remembers syntax colors that have become visible in TextKit.
  ///
  /// - Parameters:
  ///   - textStorage: The storage containing the current source revision.
  ///   - baseColor: The theme color that does not represent syntax.
  ///   - establishedColors: Syntax colors retained across later revisions.
  private func retainSyntaxColors(
    in textStorage: NSTextStorage,
    excluding baseColor: UIColor?,
    establishedColors: inout [Int: UIColor]
  ) {
    for (offset, color) in allForegroundColors(in: textStorage).enumerated()
    where color != baseColor {
      if let color {
        establishedColors[offset] = color
      }
    }
  }

  /// Converts a renderer-neutral theme color for native comparisons.
  ///
  /// - Parameter color: The optional sRGB color supplied by the theme.
  /// - Returns: The equivalent UIKit color, or `nil` when none is supplied.
  private func nativeColor(_ color: HighlightColor?) -> UIColor? {
    guard let color else {
      return nil
    }

    return UIColor(
      red: CGFloat(color.red) / 255,
      green: CGFloat(color.green) / 255,
      blue: CGFloat(color.blue) / 255,
      alpha: CGFloat(color.alpha) / 255
    )
  }

  /// Checks rendered colors against a fresh one-shot highlighter snapshot.
  ///
  /// - Parameters:
  ///   - textStorage: The storage containing the completed streaming result.
  ///   - source: The complete source used for the reference snapshot.
  /// - Throws: ``HighlighterError`` or ``TextKitRenderingError`` when the
  ///   reference source cannot be highlighted or rendered.
  private func expectExactHighlighting(
    in textStorage: NSTextStorage,
    source: String
  ) async throws {
    let highlighter = try Highlighter()
    let snapshot = try highlighter.highlight(source, as: .swift)
    let referenceStorage = NSTextStorage(string: source)
    let renderer = TextKitHighlightRenderer(
      theme: .rorkDark,
      font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    )

    try renderer.render(snapshot, in: referenceStorage)
    #expect(
      allForegroundColors(in: textStorage)
        == allForegroundColors(in: referenceStorage)
    )
  }

  /// Returns cumulative source revisions produced by fixed-size chunks.
  ///
  /// - Parameters:
  ///   - source: The complete source reconstructed by the revisions.
  ///   - chunkSize: The maximum number of characters added per revision.
  /// - Returns: Every cumulative source revision in streaming order.
  private func streamedRevisions(
    of source: String,
    chunkSize: Int
  ) -> [String] {
    var revisions: [String] = []
    var end = source.startIndex

    while end < source.endIndex {
      end =
        source.index(
          end,
          offsetBy: chunkSize,
          limitedBy: source.endIndex
        ) ?? source.endIndex
      revisions.append(String(source[..<end]))
    }

    return revisions
  }

  /// Holds the Swift fixture emitted by the example app.
  private var swiftSource: String {
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

    /// Matches the example app's rapid source cadence.
    static let streamingInterval = Duration.milliseconds(12)

  }
}
