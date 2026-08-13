import Foundation
import RorkHighlighter

/// Holds syntax styles that remain stable during append-only streaming.
struct StreamingHighlightPresentation {
  /// Holds the snapshot represented by the visible syntax attributes.
  let snapshot: HighlightSnapshot

  /// Holds source offsets whose first resolved syntax style is retained.
  private let styledOffsets: IndexSet

  /// Creates presentation state for one parser snapshot.
  ///
  /// The snapshot is reduced to disjoint visible styles so later append-only
  /// updates can preserve the first syntax style resolved for each offset.
  ///
  /// - Parameters:
  ///   - snapshot: The parser snapshot to present.
  ///   - theme: The theme used to identify visible syntax styles.
  init(
    snapshot: HighlightSnapshot,
    theme: HighlightTheme
  ) {
    let highlights = Self.visibleHighlights(
      in: snapshot,
      theme: theme
    )
    self.snapshot = HighlightSnapshot(
      text: snapshot.text,
      language: snapshot.language,
      revision: snapshot.revision,
      highlights: highlights
    )
    self.styledOffsets = IndexSet(
      highlights.flatMap { $0.range.integerRange }
    )
  }

  /// Advances presentation state without replacing an established syntax style.
  ///
  /// - Parameters:
  ///   - update: The exact parser update for the new source revision.
  ///   - theme: The theme used to identify visible syntax styles.
  /// - Returns: The adapted renderer update and the resulting presentation.
  func applying(
    _ update: HighlightUpdate,
    theme: HighlightTheme
  ) -> (
    update: HighlightUpdate,
    presentation: Self
  ) {
    guard
      update.snapshot.language == snapshot.language,
      update.snapshot.text.hasPrefix(snapshot.text)
    else {
      return Self.replacing(update, theme: theme)
    }

    var highlights = snapshot.highlights
    var styledOffsets = styledOffsets
    var addedOffsets = IndexSet()

    for candidate in Self.visibleHighlights(
      in: update.snapshot,
      theme: theme
    ) {
      var newOffsets = IndexSet(integersIn: candidate.range.integerRange)
      newOffsets.subtract(styledOffsets)
      highlights += newOffsets.rangeView.map { range in
        HighlightSpan(
          scopeComponents: candidate.scopeComponents,
          range: UTF16Range(range)
        )
      }
      styledOffsets.formUnion(newOffsets)
      addedOffsets.formUnion(newOffsets)
    }

    let snapshot = HighlightSnapshot(
      text: update.snapshot.text,
      language: update.snapshot.language,
      revision: update.snapshot.revision,
      highlights: highlights.sorted()
    )
    let presentation = Self(
      snapshot: snapshot,
      styledOffsets: styledOffsets
    )
    let update = HighlightUpdate(
      replacedRange: update.replacedRange,
      replacementRange: update.replacementRange,
      invalidatedRanges: addedOffsets.rangeView.map(UTF16Range.init),
      snapshot: snapshot
    )

    return (update, presentation)
  }

  /// Creates state from already selected presentation values.
  ///
  /// - Parameters:
  ///   - snapshot: The snapshot represented by visible attributes.
  ///   - styledOffsets: The offsets whose syntax styles are fixed.
  private init(
    snapshot: HighlightSnapshot,
    styledOffsets: IndexSet
  ) {
    self.snapshot = snapshot
    self.styledOffsets = styledOffsets
  }

  /// Replaces stable state when an update is not an append.
  ///
  /// - Parameters:
  ///   - update: The parser update whose edit metadata is retained.
  ///   - theme: The theme used to build replacement state.
  /// - Returns: The adapted update and replacement presentation.
  private static func replacing(
    _ update: HighlightUpdate,
    theme: HighlightTheme
  ) -> (
    update: HighlightUpdate,
    presentation: Self
  ) {
    let presentation = Self(
      snapshot: update.snapshot,
      theme: theme
    )
    return (
      HighlightUpdate(
        replacedRange: update.replacedRange,
        replacementRange: update.replacementRange,
        invalidatedRanges: update.invalidatedRanges,
        snapshot: presentation.snapshot
      ),
      presentation
    )
  }

  /// Resolves disjoint nonbase captures after applying overlap precedence.
  ///
  /// - Parameters:
  ///   - snapshot: The parser snapshot whose captures are inspected.
  ///   - theme: The theme used to resolve capture styles.
  /// - Returns: Disjoint highlights that differ from the base theme style.
  private static func visibleHighlights(
    in snapshot: HighlightSnapshot,
    theme: HighlightTheme
  ) -> [HighlightSpan] {
    let sourceOffsets = 0..<snapshot.text.utf16.count
    var claimedOffsets = IndexSet()
    var result: [HighlightSpan] = []

    for highlight in snapshot.styledHighlights(using: theme).reversed() {
      let lowerBound = max(sourceOffsets.lowerBound, highlight.range.location)
      let upperBound = min(sourceOffsets.upperBound, highlight.range.upperBound)
      guard lowerBound < upperBound else {
        continue
      }

      let offsets = IndexSet(integersIn: lowerBound..<upperBound)
      var visibleOffsets = offsets
      visibleOffsets.subtract(claimedOffsets)
      claimedOffsets.formUnion(offsets)

      guard highlight.style != theme.baseStyle else {
        continue
      }

      result += visibleOffsets.rangeView.map { range in
        HighlightSpan(
          scopeComponents: highlight.span.scopeComponents,
          range: UTF16Range(range)
        )
      }
    }

    return result.sorted()
  }
}

extension UTF16Range {
  /// Creates a UTF-16 range from integer bounds.
  ///
  /// - Parameter range: The half-open integer range to represent.
  fileprivate init(_ range: Range<Int>) {
    self.init(
      location: range.lowerBound,
      length: range.count
    )
  }

  /// Returns the half-open integer bounds represented by this range.
  fileprivate var integerRange: Range<Int> {
    location..<upperBound
  }
}
