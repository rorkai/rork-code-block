import RorkHighlighter
import Testing
import UIKit

@_spi(Benchmarking) @testable import RorkCodeBlock

/// Verifies incremental measurement of logical source lines.
@Suite("Code line width cache")
struct CodeLineWidthCacheTests {
  /// Verifies that source edits replace only the affected line records.
  @Test("Tracks edits that widen and join lines")
  func tracksEditsThatWidenAndJoinLines() {
    var source = "short\nwidest line\nend"
    let attributedSource = styledSource(source)
    var cache = CodeLineWidthCache()
    cache.rebuild(from: attributedSource)

    let widenedSource = "short\nwidest line\nend becomes much wider"
    applyChange(
      from: source,
      to: widenedSource,
      in: attributedSource,
      cache: &cache
    )
    source = widenedSource

    #expect(cache.widestLineWidth == completeWidth(of: attributedSource))

    let joinedSource = "shortwidest line\nend becomes much wider"
    applyChange(
      from: source,
      to: joinedSource,
      in: attributedSource,
      cache: &cache
    )

    #expect(cache.widestLineWidth == completeWidth(of: attributedSource))
  }

  /// Verifies that appending after a trailing newline measures its empty line.
  @Test("Tracks a trailing empty line")
  func tracksTrailingEmptyLine() {
    let source = "a\n"
    let attributedSource = styledSource(source)
    var cache = CodeLineWidthCache()
    cache.rebuild(from: attributedSource)
    let updatedSource = "a\na newly appended widest line"

    applyChange(
      from: source,
      to: updatedSource,
      in: attributedSource,
      cache: &cache
    )

    #expect(cache.widestLineWidth == completeWidth(of: attributedSource))
  }

  /// Verifies that incremental syntax attributes update affected line widths.
  @Test("Remeasures lines whose font traits change")
  func remeasuresLinesWhoseFontTraitsChange() {
    let source = "ordinary width\nsmall"
    let attributedSource = styledSource(source)
    var cache = CodeLineWidthCache()
    cache.rebuild(from: attributedSource)

    let secondLineRange = NSRange(location: 15, length: 5)
    attributedSource.addAttribute(
      .font,
      value: UIFont.monospacedSystemFont(ofSize: 36, weight: .bold),
      range: secondLineRange
    )
    cache.remeasure(
      linesIntersecting: [
        UTF16Range(
          location: secondLineRange.location,
          length: secondLineRange.length
        )
      ],
      in: attributedSource
    )

    #expect(cache.widestLineWidth == completeWidth(of: attributedSource))
  }

  /// Applies one complete source revision to storage and its measurement cache.
  ///
  /// - Parameters:
  ///   - oldSource: The source currently represented by the storage.
  ///   - newSource: The complete source requested by the next revision.
  ///   - attributedSource: The mutable attributed storage to update.
  ///   - cache: The line measurement cache matching the old source.
  private func applyChange(
    from oldSource: String,
    to newSource: String,
    in attributedSource: NSMutableAttributedString,
    cache: inout CodeLineWidthCache
  ) {
    guard let edit = SourceEdit.difference(from: oldSource, to: newSource) else {
      Issue.record("Expected the fixture source to change")
      return
    }

    attributedSource.replaceCharacters(
      in: NSRange(location: edit.range.location, length: edit.range.length),
      with: edit.replacement
    )
    attributedSource.addAttribute(
      .font,
      value: Fixture.font,
      range: NSRange(location: 0, length: attributedSource.length)
    )
    cache.update(after: edit, in: attributedSource)
  }

  /// Creates attributed source using the stable test font.
  ///
  /// - Parameter source: The plain source to place in mutable storage.
  /// - Returns: Mutable source with a monospaced font on every code unit.
  private func styledSource(_ source: String) -> NSMutableAttributedString {
    NSMutableAttributedString(
      string: source,
      attributes: [.font: Fixture.font]
    )
  }

  /// Measures every logical line to provide an independent expected width.
  ///
  /// - Parameter attributedSource: The exact attributed source to measure.
  /// - Returns: The complete-scan width including the rounding allowance.
  private func completeWidth(
    of attributedSource: NSAttributedString
  ) -> CGFloat {
    let source = attributedSource.string as NSString
    var widestWidth = CGFloat.zero

    source.enumerateSubstrings(
      in: NSRange(location: 0, length: source.length),
      options: [.byLines, .substringNotRequired]
    ) { _, range, _, _ in
      widestWidth = max(
        widestWidth,
        attributedSource.attributedSubstring(from: range).size().width
      )
    }

    return ceil(widestWidth) + Fixture.fractionalWidthAllowance
  }

  /// Stores the stable visual values shared by width cache tests.
  private enum Fixture {
    /// Uses the same font family as production source rendering.
    static let font = UIFont.monospacedSystemFont(
      ofSize: 15,
      weight: .regular
    )

    /// Matches the cache allowance that protects the final glyph.
    static let fractionalWidthAllowance: CGFloat = 2
  }
}
