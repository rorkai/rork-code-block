import RorkHighlighter

/// Selects the syntax ranges rendered for one changing source revision.
struct StreamingRenderingPlan {
  /// Holds the update passed to the TextKit renderer.
  let update: HighlightUpdate

  /// Records whether an exact complete render should follow after updates pause.
  let requiresSettledRender: Bool

  /// Creates a rendering plan that keeps completed lines visually stable.
  ///
  /// Tree-sitter can reinterpret an otherwise complete declaration while the
  /// source ends in an unfinished expression. Append-only streams therefore
  /// refresh the active line and new suffix while retaining completed lines.
  /// Other edits continue to use Tree-sitter's complete invalidation ranges.
  ///
  /// - Parameters:
  ///   - update: The incremental highlighting update for the new source.
  ///   - edit: The source replacement that produced the update.
  ///   - previousSource: The source represented before the replacement.
  init(
    update: HighlightUpdate,
    after edit: SourceEdit,
    in previousSource: String
  ) {
    let previousLength = previousSource.utf16.count
    guard
      edit.range == UTF16Range(location: previousLength, length: 0),
      !edit.replacement.isEmpty
    else {
      self.update = update
      self.requiresSettledRender = false
      return
    }

    let lineStart = Self.activeLineStart(in: previousSource)
    let sourceLength = update.snapshot.text.utf16.count
    let activeSuffix = UTF16Range(
      location: lineStart,
      length: sourceLength - lineStart
    )

    self.update = HighlightUpdate(
      replacedRange: update.replacedRange,
      replacementRange: update.replacementRange,
      invalidatedRanges: [activeSuffix],
      snapshot: update.snapshot
    )
    self.requiresSettledRender = true
  }

  /// Returns the UTF-16 start of the final logical source line.
  ///
  /// - Parameter source: The source that existed before an append.
  /// - Returns: The offset immediately after its final newline, or zero.
  private static func activeLineStart(in source: String) -> Int {
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
