import Foundation
import RorkHighlighter
import Testing
import UIKit

@testable @_spi(Benchmarking) import RorkCodeBlock

/// Verifies that one code block reuses ordered Tree-sitter revisions.
@Suite("Streaming highlighter")
struct StreamingHighlighterTests {
  /// Verifies that coalescing cannot leave recovery captures in the final frame.
  @MainActor
  @Test("Matches exact colors after coalesced Swift revisions")
  func matchesExactColorsAfterCoalescedSwiftRevisions() async throws {
    for stride in 1...12 {
      let revisions = streamedRevisions(of: swiftSource, chunkSize: 7)
      let selectedRevisions = revisions.enumerated().compactMap { index, source in
        (index + 1).isMultiple(of: stride) || index == revisions.indices.last
          ? source
          : nil
      }
      let differingOffsets = try await differingFinalOffsets(
        for: selectedRevisions
      )

      #expect(
        differingOffsets.isEmpty,
        "Stride \(stride) changed UTF-16 offsets \(differingOffsets)"
      )
    }
  }

  /// Verifies that completed lines stay stable while incomplete Swift streams.
  @MainActor
  @Test("Keeps completed Swift lines stable while streaming")
  func keepsCompletedSwiftLinesStableWhileStreaming() async throws {
    let streamingHighlighter = StreamingHighlighter()
    let referenceHighlighter = try Highlighter()
    let font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    let renderer = TextKitHighlightRenderer(theme: .rorkDark, font: font)
    let textStorage = NSTextStorage()
    var stableImportColor: UIColor?
    var observedStableImport = false
    var latestSnapshot: HighlightSnapshot?
    var renderingState: StreamingRenderingState?

    for source in streamedRevisions(of: swiftSource, chunkSize: 7) {
      let result = try await streamingHighlighter.highlight(source, as: .swift)
      latestSnapshot = result.snapshot

      switch result {
      case .snapshot(let snapshot):
        textStorage.setAttributedString(NSAttributedString(string: source))
        try renderer.render(snapshot, in: textStorage)
        renderingState = StreamingRenderingState(snapshot: snapshot)

      case .update(let previousSource, let edit, let update):
        textStorage.replaceCharacters(
          in: NSRange(location: edit.range.location, length: edit.range.length),
          with: edit.replacement
        )
        let previousState = try #require(renderingState)
        #expect(previousState.snapshot.text == previousSource)
        let plan = StreamingRenderingPlan(
          update: update,
          after: edit,
          from: previousState
        )
        try renderer.render(plan.update, in: textStorage)
        renderingState = plan.state
      }

      if source.utf16.count >= 21 {
        let importColor =
          textStorage.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
          ) as? UIColor
        if let stableImportColor {
          #expect(
            importColor == stableImportColor,
            "A settled import changed color at length \(source.utf16.count)"
          )
          observedStableImport = true
        } else {
          stableImportColor = importColor
        }
      }
    }

    #expect(observedStableImport)

    guard let latestSnapshot else {
      Issue.record("Expected a final streamed snapshot")
      return
    }

    let referenceSnapshot = try referenceHighlighter.highlight(
      swiftSource,
      as: .swift
    )
    let referenceStorage = NSTextStorage(string: swiftSource)
    let referenceRenderer = TextKitHighlightRenderer(
      theme: .rorkDark,
      font: font
    )
    try referenceRenderer.render(referenceSnapshot, in: referenceStorage)

    let streamingColors = foregroundColors(in: textStorage)
    let referenceColors = foregroundColors(in: referenceStorage)
    let recoloredOffsets = zip(streamingColors, referenceColors).enumerated()
      .compactMap { offset, colors in
        colors.0 == colors.1 ? nil : offset
      }

    #expect(
      recoloredOffsets.isEmpty,
      "A settled render would recolor UTF-16 offsets \(recoloredOffsets)"
    )

    try renderer.render(latestSnapshot, in: textStorage)
    #expect(foregroundColors(in: textStorage) == referenceColors)
  }

  /// Verifies that nonappend edits retain Tree-sitter's invalidation ranges.
  @Test("Keeps full invalidation for ordinary edits")
  func keepsFullInvalidationForOrdinaryEdits() {
    let source = "let result = value"
    let snapshot = HighlightSnapshot(
      text: source,
      language: .swift,
      revision: 1,
      highlights: []
    )
    let update = HighlightUpdate(
      replacedRange: UTF16Range(location: 4, length: 5),
      replacementRange: UTF16Range(location: 4, length: 6),
      invalidatedRanges: [UTF16Range(location: 0, length: source.utf16.count)],
      snapshot: snapshot
    )
    let edit = SourceEdit(
      range: UTF16Range(location: 4, length: 5),
      replacement: "result"
    )

    let plan = StreamingRenderingPlan(
      update: update,
      after: edit,
      from: StreamingRenderingState(
        snapshot: HighlightSnapshot(
          text: "let value = value",
          language: .swift,
          revision: 0,
          highlights: []
        )
      )
    )

    #expect(plan.update == update)
    #expect(!plan.requiresSettledRender)
  }

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

  /// Returns the cumulative source revisions produced by fixed-size chunks.
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

  /// Returns final color differences for one streamed revision sequence.
  ///
  /// - Parameter revisions: The cumulative source revisions to process.
  /// - Returns: UTF-16 offsets whose rendered colors differ.
  @MainActor
  private func differingFinalOffsets(
    for revisions: [String]
  ) async throws -> [Int] {
    let streamingHighlighter = StreamingHighlighter()
    let referenceHighlighter = try Highlighter()
    let font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    let renderer = TextKitHighlightRenderer(theme: .rorkDark, font: font)
    let textStorage = NSTextStorage()
    var renderingState: StreamingRenderingState?

    for source in revisions {
      let result = try await streamingHighlighter.highlight(source, as: .swift)

      switch result {
      case .snapshot(let snapshot):
        textStorage.setAttributedString(NSAttributedString(string: source))
        try renderer.render(snapshot, in: textStorage)
        renderingState = StreamingRenderingState(snapshot: snapshot)

      case .update(_, let edit, let update):
        textStorage.replaceCharacters(
          in: NSRange(location: edit.range.location, length: edit.range.length),
          with: edit.replacement
        )
        let previousState = try #require(renderingState)
        let plan = StreamingRenderingPlan(
          update: update,
          after: edit,
          from: previousState
        )
        try renderer.render(plan.update, in: textStorage)
        renderingState = plan.state
      }
    }

    let referenceSnapshot = try referenceHighlighter.highlight(
      swiftSource,
      as: .swift
    )
    let referenceStorage = NSTextStorage(string: swiftSource)
    let referenceRenderer = TextKitHighlightRenderer(
      theme: .rorkDark,
      font: font
    )
    try referenceRenderer.render(referenceSnapshot, in: referenceStorage)

    return zip(
      foregroundColors(in: textStorage),
      foregroundColors(in: referenceStorage)
    ).enumerated().compactMap { offset, colors in
      colors.0 == colors.1 ? nil : offset
    }
  }

  /// Returns the foreground color at every UTF-16 offset in TextKit storage.
  ///
  /// - Parameter textStorage: The storage whose rendered colors are inspected.
  /// - Returns: Colors ordered by their corresponding UTF-16 offsets.
  @MainActor
  private func foregroundColors(
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

  /// Holds the complete Swift fixture used by streaming regression tests.
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
}
