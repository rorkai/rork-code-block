import RorkHighlighter

/// Holds the syntax state already presented by an append-only stream.
struct StreamingRenderingState {
  /// Holds the snapshot represented by the rendered TextKit attributes.
  let snapshot: HighlightSnapshot

  /// Retains captures established when their source lines became complete.
  fileprivate let protectedHighlights: [HighlightSpan]

  /// Marks the source prefix whose completed lines have been recorded.
  fileprivate let protectedPrefixEnd: Int

  /// Creates initial rendering state from one complete parser snapshot.
  ///
  /// Captures in completed lines become stable immediately. The final logical
  /// line remains free to evolve if later source is appended to it.
  ///
  /// - Parameter snapshot: The snapshot rendered before the next source edit.
  init(snapshot: HighlightSnapshot) {
    let protectedPrefixEnd = Self.completedPrefixEnd(in: snapshot.text)
    self.init(
      snapshot: snapshot,
      protectedHighlights: snapshot.highlights.filter {
        $0.range.upperBound <= protectedPrefixEnd
      },
      protectedPrefixEnd: protectedPrefixEnd
    )
  }

  /// Creates state with an explicit completed-line capture history.
  ///
  /// - Parameters:
  ///   - snapshot: The snapshot represented by rendered attributes.
  ///   - protectedHighlights: Captures fixed when their lines completed.
  ///   - protectedPrefixEnd: The end of the recorded complete-line prefix.
  fileprivate init(
    snapshot: HighlightSnapshot,
    protectedHighlights: [HighlightSpan],
    protectedPrefixEnd: Int
  ) {
    self.snapshot = snapshot
    self.protectedHighlights = protectedHighlights
    self.protectedPrefixEnd = protectedPrefixEnd
  }

  /// Returns the UTF-16 start of the final logical source line.
  ///
  /// - Parameter source: The source whose completed prefix is requested.
  /// - Returns: The offset immediately after its final newline, or zero.
  fileprivate static func completedPrefixEnd(in source: String) -> Int {
    let codeUnits = source.utf16
    guard let newline = codeUnits.lastIndex(of: 0x0A) else {
      return 0
    }

    return codeUnits.distance(
      from: codeUnits.startIndex,
      to: codeUnits.index(after: newline)
    )
  }
}

/// Selects the syntax ranges rendered for one changing source revision.
struct StreamingRenderingPlan {
  /// Holds the update passed to the TextKit renderer.
  let update: HighlightUpdate

  /// Holds the display state produced after applying ``update``.
  let state: StreamingRenderingState

  /// Records whether an exact complete render should follow after updates pause.
  let requiresSettledRender: Bool

  /// Creates a rendering plan that keeps completed lines visually stable.
  ///
  /// Tree-sitter can reinterpret otherwise complete code while the source ends
  /// in an unfinished expression. Append-only streams preserve the captures
  /// established when each line completed while accepting captures for text
  /// that was unresolved at that point. Other edits use the parser update
  /// without adaptation.
  ///
  /// - Parameters:
  ///   - update: The incremental highlighting update for the new source.
  ///   - edit: The source replacement that produced the update.
  ///   - previousState: The rendered state before the replacement.
  init(
    update: HighlightUpdate,
    after edit: SourceEdit,
    from previousState: StreamingRenderingState
  ) {
    let previousSnapshot = previousState.snapshot
    let previousSource = previousSnapshot.text
    let previousLength = previousSource.utf16.count
    guard
      edit.range == UTF16Range(location: previousLength, length: 0),
      !edit.replacement.isEmpty,
      previousSnapshot.language == update.snapshot.language
    else {
      self.update = update
      self.state = StreamingRenderingState(snapshot: update.snapshot)
      self.requiresSettledRender = false
      return
    }

    let protectedPrefixEnd = StreamingRenderingState.completedPrefixEnd(
      in: update.snapshot.text
    )
    var protectedHighlights = previousState.protectedHighlights
    var knownProtectedHighlights = Set(protectedHighlights)
    protectedHighlights += update.snapshot.highlights.filter { highlight in
      highlight.range.upperBound > previousState.protectedPrefixEnd
        && highlight.range.upperBound <= protectedPrefixEnd
        && knownProtectedHighlights.insert(highlight).inserted
    }

    var knownHighlights = Set(update.snapshot.highlights)
    let retainedHighlights = protectedHighlights.filter {
      knownHighlights.insert($0).inserted
    }
    let snapshot = HighlightSnapshot(
      text: update.snapshot.text,
      language: update.snapshot.language,
      revision: update.snapshot.revision,
      highlights: update.snapshot.highlights + retainedHighlights
    )
    let activeSuffix = UTF16Range(
      location: protectedPrefixEnd,
      length: snapshot.text.utf16.count - protectedPrefixEnd
    )
    let previousHighlights = Set(previousSnapshot.highlights)
    let nextHighlights = Set(snapshot.highlights)
    let displayChanges =
      previousHighlights
      .symmetricDifference(nextHighlights)
      .map(\.range)

    self.update = HighlightUpdate(
      replacedRange: update.replacedRange,
      replacementRange: update.replacementRange,
      invalidatedRanges:
        update.invalidatedRanges + displayChanges + [activeSuffix],
      snapshot: snapshot
    )
    self.state = StreamingRenderingState(
      snapshot: snapshot,
      protectedHighlights: protectedHighlights,
      protectedPrefixEnd: protectedPrefixEnd
    )
    self.requiresSettledRender = true
  }
}
