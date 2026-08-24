import Foundation
import RorkHighlighter

/// Presents settled syntax exactly while the uncertain tail stays neutral.
///
/// Rork Highlighter reports how much of a streamed revision parses without
/// end-of-input recovery through `HighlightSnapshot.stableUTF16Length`. The
/// presentation shows exact captures up to that boundary and keeps the
/// speculative tail in the theme's base style.
///
/// Two rules color the region beyond the boundary. Styles that were revealed
/// earlier persist, so source drawn back into recovery keeps its last settled
/// colors instead of following the parser's temporary guesses, and it
/// resynchronizes with exact captures once the syntax settles again. Styles
/// that were never revealed appear once their classification has outlived a
/// fixed amount of appended source, because recovery guesses die within a
/// short stretch of further input while trustworthy classifications hold
/// indefinitely. This keeps multiline constructs, such as a call with a
/// streaming trailing closure, from staying neutral until their closing
/// braces arrive, at any chunk size.
struct StreamingHighlightPresentation {
  /// Holds the snapshot represented by the visible syntax attributes.
  let snapshot: HighlightSnapshot

  /// Records the document length at which each unrevealed span appeared.
  ///
  /// A span leaves the map as soon as one revision stops reporting it, so a
  /// surviving entry means the classification held across every parse since
  /// the recorded length.
  private let firstObservedLengths: [HighlightSpan: Int]

  /// Creates presentation state for the first parsed revision.
  ///
  /// - Parameters:
  ///   - snapshot: The exact parser snapshot to present.
  ///   - theme: The theme used to identify visible syntax styles.
  init(
    snapshot: HighlightSnapshot,
    theme: HighlightTheme
  ) {
    let stableBoundary = Self.stableBoundary(of: snapshot)
    let exactRuns = Self.visibleHighlights(in: snapshot, theme: theme)
    let (settled, speculative) = Self.split(exactRuns, at: stableBoundary)
    let documentLength = snapshot.text.utf16.count

    self.snapshot = HighlightSnapshot(
      text: snapshot.text,
      language: snapshot.language,
      revision: snapshot.revision,
      highlights: settled,
      stableUTF16Length: snapshot.stableUTF16Length
    )
    self.firstObservedLengths = Dictionary(
      uniqueKeysWithValues: speculative.map { ($0, documentLength) }
    )
  }

  /// Advances the presentation with the exact update for a new revision.
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

    let exact = update.snapshot
    let stableBoundary = Self.stableBoundary(of: exact)
    let insertionPoint = update.replacedRange.location
    let insertedLength = update.replacementRange.length

    let exactRuns = Self.visibleHighlights(in: exact, theme: theme)
    let (settled, speculative) = Self.split(exactRuns, at: stableBoundary)

    // Previously revealed styles persist beyond the boundary so recovery
    // dips cannot recolor them.
    let persisted = Self.clipped(
      Self.rebasedHighlights(
        snapshot.highlights,
        insertionPoint: insertionPoint,
        insertedLength: insertedLength
      ),
      from: stableBoundary
    )

    // A speculative run reveals once it has outlived enough appended
    // input, which measures survival against the source itself rather
    // than against how often the parser sampled it.
    let documentLength = exact.text.utf16.count
    let previousLengths = Self.rebasedObservations(
      firstObservedLengths,
      insertionPoint: insertionPoint,
      insertedLength: insertedLength
    )
    var nextLengths = [HighlightSpan: Int](
      minimumCapacity: speculative.count
    )
    var confirmed: [HighlightSpan] = []
    for run in speculative {
      let firstObserved = previousLengths[run] ?? documentLength
      nextLengths[run] = firstObserved
      if documentLength - firstObserved >= Self.confirmationInputLength {
        confirmed.append(run)
      }
    }

    var highlights = settled + persisted
    highlights += Self.subtracting(confirmed, overlapping: persisted)
    highlights.sort()

    let presented = HighlightSnapshot(
      text: exact.text,
      language: exact.language,
      revision: exact.revision,
      highlights: highlights,
      stableUTF16Length: exact.stableUTF16Length
    )
    let presentation = Self(
      snapshot: presented,
      firstObservedLengths: nextLengths
    )
    let invalidatedRanges = Self.changedRanges(
      from: Self.rebasedHighlights(
        snapshot.highlights,
        insertionPoint: insertionPoint,
        insertedLength: insertedLength
      ),
      to: highlights
    )
    let adaptedUpdate = HighlightUpdate(
      replacedRange: update.replacedRange,
      replacementRange: update.replacementRange,
      invalidatedRanges: invalidatedRanges,
      snapshot: presented
    )

    return (adaptedUpdate, presentation)
  }

  /// Creates state from already selected presentation values.
  ///
  /// - Parameters:
  ///   - snapshot: The snapshot represented by visible attributes.
  ///   - firstObservedLengths: The first-observation lengths of unrevealed
  ///     spans.
  private init(
    snapshot: HighlightSnapshot,
    firstObservedLengths: [HighlightSpan: Int]
  ) {
    self.snapshot = snapshot
    self.firstObservedLengths = firstObservedLengths
  }

  /// Replaces presentation state when an update is not an append.
  ///
  /// The rebuilt state reveals only the settled prefix of the new revision,
  /// and the complete document is invalidated because previously revealed
  /// styles have no defensible positions after an arbitrary edit.
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
    let documentRange = UTF16Range(
      location: 0,
      length: update.snapshot.text.utf16.count
    )
    return (
      HighlightUpdate(
        replacedRange: update.replacedRange,
        replacementRange: update.replacementRange,
        invalidatedRanges: documentRange.length > 0 ? [documentRange] : [],
        snapshot: presentation.snapshot
      ),
      presentation
    )
  }

  /// Holds the appended input an unsettled classification must outlive.
  ///
  /// Tree-sitter's recovery guesses were observed dying within 28 UTF-16
  /// units of appended source, while genuinely settled classifications held
  /// indefinitely, so surviving 42 units separates the two with margin.
  /// Measuring survival in source units keeps the rule independent of chunk
  /// size and coalescing. Counting parser observations instead was tried
  /// and dropped, because character-sized chunks made a handful of
  /// observations span too little input to outlive recovery guesses.
  private static let confirmationInputLength = 42

  /// Returns the settled prefix length reported by a parser snapshot.
  ///
  /// A snapshot without parse information reveals everything, which matches
  /// the exact behavior of non-streaming modes.
  ///
  /// - Parameter snapshot: The exact parser snapshot.
  /// - Returns: The boundary below which captures can be shown.
  private static func stableBoundary(
    of snapshot: HighlightSnapshot
  ) -> Int {
    let documentLength = snapshot.text.utf16.count
    guard let stableUTF16Length = snapshot.stableUTF16Length else {
      return documentLength
    }
    return min(max(stableUTF16Length, 0), documentLength)
  }

  /// Resolves the disjoint nonbase captures of a complete snapshot.
  ///
  /// - Parameters:
  ///   - snapshot: The parser snapshot whose captures are inspected.
  ///   - theme: The theme used to resolve capture styles.
  /// - Returns: Disjoint sorted highlights that differ from the base style.
  private static func visibleHighlights(
    in snapshot: HighlightSnapshot,
    theme: HighlightTheme
  ) -> [HighlightSpan] {
    var claimedOffsets = IndexSet()
    var result: [HighlightSpan] = []

    for highlight in snapshot.styledHighlights(using: theme).reversed() {
      let lowerBound = max(0, highlight.range.location)
      let upperBound = min(
        snapshot.text.utf16.count,
        highlight.range.upperBound
      )
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

  /// Splits disjoint runs into settled and speculative parts at a boundary.
  ///
  /// A run straddling the boundary contributes its leading part to the
  /// settled zone and its trailing part to the speculative zone.
  ///
  /// - Parameters:
  ///   - runs: The disjoint sorted nonbase runs of one snapshot.
  ///   - boundary: The offset where speculative syntax begins.
  /// - Returns: The settled runs and the speculative runs.
  private static func split(
    _ runs: [HighlightSpan],
    at boundary: Int
  ) -> (settled: [HighlightSpan], speculative: [HighlightSpan]) {
    var settled: [HighlightSpan] = []
    var speculative: [HighlightSpan] = []

    for run in runs {
      if run.range.upperBound <= boundary {
        settled.append(run)
      } else if run.range.location >= boundary {
        speculative.append(run)
      } else {
        settled.append(
          HighlightSpan(
            scopeComponents: run.scopeComponents,
            range: UTF16Range(run.range.location..<boundary)
          )
        )
        speculative.append(
          HighlightSpan(
            scopeComponents: run.scopeComponents,
            range: UTF16Range(boundary..<run.range.upperBound)
          )
        )
      }
    }

    return (settled, speculative)
  }

  /// Rebases previously tracked spans across one insertion.
  ///
  /// The presentation reaches this path only for edits that preserve the
  /// previous source as a prefix, so the edit inserts text without removing
  /// any. Spans after the insertion point move with the inserted length.
  ///
  /// - Parameters:
  ///   - highlights: The disjoint sorted spans of the previous presentation.
  ///   - insertionPoint: The UTF-16 offset receiving inserted source.
  ///   - insertedLength: The UTF-16 length of the inserted source.
  /// - Returns: The spans at their positions in the new revision.
  private static func rebasedHighlights(
    _ highlights: [HighlightSpan],
    insertionPoint: Int,
    insertedLength: Int
  ) -> [HighlightSpan] {
    guard insertedLength > 0 else {
      return highlights
    }

    return highlights.map { highlight in
      guard highlight.range.location >= insertionPoint else {
        return highlight
      }
      return HighlightSpan(
        scopeComponents: highlight.scopeComponents,
        range: UTF16Range(
          location: highlight.range.location + insertedLength,
          length: highlight.range.length
        )
      )
    }
  }

  /// Rebases first-observation lengths across one insertion.
  ///
  /// - Parameters:
  ///   - observations: The first-observation lengths keyed by span.
  ///   - insertionPoint: The UTF-16 offset receiving inserted source.
  ///   - insertedLength: The UTF-16 length of the inserted source.
  /// - Returns: The lengths keyed by the spans' new positions.
  private static func rebasedObservations(
    _ observations: [HighlightSpan: Int],
    insertionPoint: Int,
    insertedLength: Int
  ) -> [HighlightSpan: Int] {
    guard insertedLength > 0 else {
      return observations
    }

    var rebased = [HighlightSpan: Int](minimumCapacity: observations.count)
    for (span, firstObserved) in observations {
      guard span.range.location >= insertionPoint else {
        rebased[span] = firstObserved
        continue
      }
      rebased[
        HighlightSpan(
          scopeComponents: span.scopeComponents,
          range: UTF16Range(
            location: span.range.location + insertedLength,
            length: span.range.length
          )
        )
      ] = firstObserved
    }
    return rebased
  }

  /// Returns previously revealed spans clipped to the speculative zone.
  ///
  /// - Parameters:
  ///   - highlights: The rebased spans of the previous presentation.
  ///   - lowerBound: The current stability boundary.
  /// - Returns: The retained spans at or beyond the boundary.
  private static func clipped(
    _ highlights: [HighlightSpan],
    from lowerBound: Int
  ) -> [HighlightSpan] {
    highlights.compactMap { highlight in
      let clippedLower = max(highlight.range.location, lowerBound)
      guard clippedLower < highlight.range.upperBound else {
        return nil
      }
      return HighlightSpan(
        scopeComponents: highlight.scopeComponents,
        range: UTF16Range(clippedLower..<highlight.range.upperBound)
      )
    }
  }

  /// Returns confirmed runs reduced to offsets no revealed span covers.
  ///
  /// Revealed styles stay authoritative until the stability boundary passes
  /// them, so a confirmed classification fills gaps instead of recoloring.
  ///
  /// - Parameters:
  ///   - confirmed: The confirmed speculative runs.
  ///   - persisted: The previously revealed spans in the speculative zone.
  /// - Returns: The confirmed run parts that do not overlap revealed spans.
  private static func subtracting(
    _ confirmed: [HighlightSpan],
    overlapping persisted: [HighlightSpan]
  ) -> [HighlightSpan] {
    guard !persisted.isEmpty else {
      return confirmed
    }

    var coveredOffsets = IndexSet()
    for span in persisted {
      coveredOffsets.insert(integersIn: span.range.range)
    }

    var result: [HighlightSpan] = []
    for run in confirmed {
      var runOffsets = IndexSet(integersIn: run.range.range)
      runOffsets.subtract(coveredOffsets)
      result += runOffsets.rangeView.map { range in
        HighlightSpan(
          scopeComponents: run.scopeComponents,
          range: UTF16Range(range)
        )
      }
    }
    return result
  }

  /// Returns the regions whose presented spans differ between revisions.
  ///
  /// Both lists are disjoint and sorted, so a two-pointer walk over the
  /// symmetric difference covers every offset whose covering span appeared,
  /// disappeared, moved, or changed scope.
  ///
  /// - Parameters:
  ///   - previous: The previously presented spans in new-revision offsets.
  ///   - current: The newly presented spans.
  /// - Returns: The ranges a renderer needs to repaint.
  private static func changedRanges(
    from previous: [HighlightSpan],
    to current: [HighlightSpan]
  ) -> [UTF16Range] {
    var changed: [UTF16Range] = []
    var previousIndex = previous.startIndex
    var currentIndex = current.startIndex

    while previousIndex < previous.endIndex,
      currentIndex < current.endIndex
    {
      let previousSpan = previous[previousIndex]
      let currentSpan = current[currentIndex]
      if previousSpan == currentSpan {
        previousIndex += 1
        currentIndex += 1
      } else if previousSpan < currentSpan {
        changed.append(previousSpan.range)
        previousIndex += 1
      } else {
        changed.append(currentSpan.range)
        currentIndex += 1
      }
    }
    changed.append(
      contentsOf: previous[previousIndex...].map(\.range)
    )
    changed.append(
      contentsOf: current[currentIndex...].map(\.range)
    )

    return changed
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
}
