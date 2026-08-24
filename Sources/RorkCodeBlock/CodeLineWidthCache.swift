import RorkHighlighter
import UIKit

/// Retains logical line measurements for incremental horizontal sizing.
///
/// Source edits replace only the measurements for lines touching the edit.
/// Syntax updates similarly remeasure only lines whose font traits may have
/// changed. Finding the maximum still scans inexpensive cached widths without
/// laying out every attributed line again.
@_spi(Benchmarking)
public struct CodeLineWidthCache {
  /// Holds the measured logical lines in source order.
  private var lines: [MeasuredLine] = []

  /// Holds the UTF-16 length represented by the cached line ranges.
  private var utf16Length = 0

  /// Returns the horizontal extent required by the widest logical line.
  public var widestLineWidth: CGFloat {
    let widestWidth = lines.lazy.map(\.width).max() ?? 0
    return ceil(widestWidth) + Metrics.fractionalWidthAllowance
  }

  /// Creates an empty logical-line measurement cache.
  public init() {}

  /// Discards measurements when wrapping makes horizontal sizing unnecessary.
  public mutating func removeAll() {
    lines.removeAll(keepingCapacity: true)
    utf16Length = 0
  }

  /// Measures every logical line after a complete storage replacement.
  ///
  /// - Parameter attributedSource: The exact attributed source drawn by TextKit.
  public mutating func rebuild(from attributedSource: NSAttributedString) {
    utf16Length = attributedSource.length
    lines = Self.measuredLines(
      in: attributedSource,
      from: 0,
      through: attributedSource.length
    )
  }

  /// Replaces line measurements affected by one source edit.
  ///
  /// The attributed source must already contain the replacement. Invalid or
  /// stale cache state falls back to a complete rebuild so geometry remains
  /// correct without complicating the rendering path.
  ///
  /// - Parameters:
  ///   - edit: The source replacement already applied to TextKit storage.
  ///   - attributedSource: The resulting attributed source.
  public mutating func update(
    after edit: SourceEdit,
    in attributedSource: NSAttributedString
  ) {
    let expectedLength =
      utf16Length - edit.range.length + edit.replacementRange.length

    guard
      edit.range.upperBound <= utf16Length,
      expectedLength == attributedSource.length,
      let firstLineIndex = lineIndex(containing: edit.range.location),
      let lastLineIndex = lineIndex(containing: edit.range.upperBound)
    else {
      rebuild(from: attributedSource)
      return
    }

    let replacementLines = Self.measuredLines(
      in: attributedSource,
      from: edit.replacementRange.location,
      through: edit.replacementRange.upperBound
    )
    let lengthDelta = attributedSource.length - utf16Length

    lines.replaceSubrange(
      firstLineIndex...lastLineIndex,
      with: replacementLines
    )

    let shiftedLineIndex = firstLineIndex + replacementLines.count
    if shiftedLineIndex < lines.endIndex, lengthDelta != 0 {
      for index in shiftedLineIndex..<lines.endIndex {
        lines[index].offset(by: lengthDelta)
      }
    }

    utf16Length = attributedSource.length
  }

  /// Remeasures lines intersecting incremental syntax rendering ranges.
  ///
  /// - Parameters:
  ///   - renderingRanges: The ranges whose syntax attributes may have changed.
  ///   - attributedSource: The resulting attributed source.
  public mutating func remeasure(
    linesIntersecting renderingRanges: [UTF16Range],
    in attributedSource: NSAttributedString
  ) {
    guard attributedSource.length == utf16Length else {
      rebuild(from: attributedSource)
      return
    }

    var affectedLineIndices: Set<Int> = []

    for range in renderingRanges where range.length > 0 {
      guard
        range.upperBound <= utf16Length,
        let firstLineIndex = lineIndex(containing: range.location),
        let lastLineIndex = lineIndex(containing: range.upperBound - 1)
      else {
        rebuild(from: attributedSource)
        return
      }

      affectedLineIndices.formUnion(firstLineIndex...lastLineIndex)
    }

    for index in affectedLineIndices {
      lines[index].remeasure(in: attributedSource)
    }
  }

  /// Returns the cached line containing one UTF-16 boundary.
  ///
  /// A boundary shared by two lines belongs to the following line. The final
  /// boundary belongs to a trailing empty line when the source ends in a line
  /// terminator and otherwise remains on the final content line.
  ///
  /// - Parameter position: The source boundary whose line is needed.
  /// - Returns: The matching cached index or `nil` for stale state.
  private func lineIndex(containing position: Int) -> Int? {
    guard
      position >= 0,
      position <= utf16Length,
      !lines.isEmpty
    else {
      return nil
    }

    var lowerBound = lines.startIndex
    var upperBound = lines.endIndex

    while lowerBound < upperBound {
      let midpoint = lowerBound + (upperBound - lowerBound) / 2

      if lines[midpoint].range.location <= position {
        lowerBound = midpoint + 1
      } else {
        upperBound = midpoint
      }
    }

    guard lowerBound > lines.startIndex else {
      return nil
    }

    return lowerBound - 1
  }

  /// Measures the consecutive logical lines containing two boundaries.
  ///
  /// - Parameters:
  ///   - attributedSource: The exact attributed source drawn by TextKit.
  ///   - firstPosition: The first UTF-16 boundary to include.
  ///   - lastPosition: The last UTF-16 boundary to include.
  /// - Returns: Complete line measurements spanning both boundaries.
  private static func measuredLines(
    in attributedSource: NSAttributedString,
    from firstPosition: Int,
    through lastPosition: Int
  ) -> [MeasuredLine] {
    let source = attributedSource.string as NSString
    let firstBounds = LineBounds(in: source, at: firstPosition)
    let lastBounds = LineBounds(in: source, at: lastPosition)
    var bounds = firstBounds
    var result: [MeasuredLine] = []

    while true {
      result.append(
        MeasuredLine(bounds: bounds, in: attributedSource)
      )

      guard bounds.range.location != lastBounds.range.location else {
        break
      }

      let nextPosition = NSMaxRange(bounds.range)
      guard nextPosition > bounds.range.location else {
        break
      }

      bounds = LineBounds(in: source, at: nextPosition)
    }

    return result
  }

  /// Stores the fixed allowance applied to measured line widths.
  private enum Metrics {
    /// Prevents a final glyph from wrapping because of fractional rounding.
    static let fractionalWidthAllowance: CGFloat = 2
  }

  /// Describes one logical line and its visible content range.
  private struct LineBounds {
    /// Holds the complete range including any line terminator.
    let range: NSRange

    /// Holds the visible range before any line terminator.
    let contentRange: NSRange

    /// Finds the logical line containing one source boundary.
    ///
    /// - Parameters:
    ///   - source: The source whose logical lines should be inspected.
    ///   - position: The UTF-16 boundary contained by the requested line.
    init(in source: NSString, at position: Int) {
      var start = 0
      var end = 0
      var contentsEnd = 0

      source.getLineStart(
        &start,
        end: &end,
        contentsEnd: &contentsEnd,
        for: NSRange(location: position, length: 0)
      )

      range = NSRange(location: start, length: end - start)
      contentRange = NSRange(
        location: start,
        length: contentsEnd - start
      )
    }
  }

  /// Stores one logical line's source ranges and measured width.
  private struct MeasuredLine {
    /// Holds the complete range including any line terminator.
    var range: NSRange

    /// Holds the visible range before any line terminator.
    var contentRange: NSRange

    /// Holds the rendered width of the visible line content.
    var width: CGFloat

    /// Measures one logical line from its exact attributed content.
    ///
    /// - Parameters:
    ///   - bounds: The complete and visible ranges of the logical line.
    ///   - attributedSource: The exact attributed source drawn by TextKit.
    init(bounds: LineBounds, in attributedSource: NSAttributedString) {
      range = bounds.range
      contentRange = bounds.contentRange
      width = Self.width(
        of: bounds.contentRange,
        in: attributedSource
      )
    }

    /// Moves both ranges after an earlier source edit.
    ///
    /// - Parameter delta: The signed UTF-16 length change before this line.
    mutating func offset(by delta: Int) {
      range.location += delta
      contentRange.location += delta
    }

    /// Updates this line after incremental syntax attributes change.
    ///
    /// - Parameter attributedSource: The exact attributed source drawn by TextKit.
    mutating func remeasure(in attributedSource: NSAttributedString) {
      width = Self.width(of: contentRange, in: attributedSource)
    }

    /// Measures the visible attributed content of one logical line.
    ///
    /// - Parameters:
    ///   - range: The visible UTF-16 range to measure.
    ///   - attributedSource: The exact attributed source drawn by TextKit.
    /// - Returns: The rendered width before rounding allowance is applied.
    private static func width(
      of range: NSRange,
      in attributedSource: NSAttributedString
    ) -> CGFloat {
      attributedSource.attributedSubstring(from: range).size().width
    }
  }
}
