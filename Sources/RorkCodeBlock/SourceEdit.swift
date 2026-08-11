import Foundation
import RorkHighlighter

/// Describes one contiguous replacement between two source revisions.
struct SourceEdit: Equatable, Sendable {
  /// Holds the UTF-16 range removed from the previous source.
  let range: UTF16Range

  /// Holds the source inserted at ``range``.
  let replacement: String

  /// Returns the UTF-16 range occupied by the replacement.
  var replacementRange: UTF16Range {
    UTF16Range(
      location: range.location,
      length: replacement.utf16.count
    )
  }

  /// Finds the smallest single replacement that transforms one source into another.
  ///
  /// The comparison works in UTF-16 because both TextKit and Rork Highlighter
  /// consume those offsets. Boundaries are widened when a matching prefix or
  /// suffix would otherwise split a Unicode scalar.
  ///
  /// - Parameters:
  ///   - oldSource: The source represented by the current revision.
  ///   - newSource: The complete source requested by the next revision.
  /// - Returns: The required replacement, or `nil` when the strings match.
  static func difference(
    from oldSource: String,
    to newSource: String
  ) -> Self? {
    guard oldSource != newSource else {
      return nil
    }

    let oldUnits = oldSource.utf16
    let newUnits = newSource.utf16
    var oldPrefix = oldUnits.startIndex
    var newPrefix = newUnits.startIndex

    while oldPrefix != oldUnits.endIndex,
      newPrefix != newUnits.endIndex,
      oldUnits[oldPrefix] == newUnits[newPrefix]
    {
      oldUnits.formIndex(after: &oldPrefix)
      newUnits.formIndex(after: &newPrefix)
    }

    while !oldUnits.isScalarBoundary(at: oldPrefix)
      || !newUnits.isScalarBoundary(at: newPrefix)
    {
      oldUnits.formIndex(before: &oldPrefix)
      newUnits.formIndex(before: &newPrefix)
    }

    var oldSuffix = oldUnits.endIndex
    var newSuffix = newUnits.endIndex

    while oldSuffix != oldPrefix, newSuffix != newPrefix {
      let previousOldIndex = oldUnits.index(before: oldSuffix)
      let previousNewIndex = newUnits.index(before: newSuffix)

      guard oldUnits[previousOldIndex] == newUnits[previousNewIndex] else {
        break
      }

      oldSuffix = previousOldIndex
      newSuffix = previousNewIndex
    }

    while !oldUnits.isScalarBoundary(at: oldSuffix)
      || !newUnits.isScalarBoundary(at: newSuffix)
    {
      oldUnits.formIndex(after: &oldSuffix)
      newUnits.formIndex(after: &newSuffix)
    }

    let location = oldUnits.distance(
      from: oldUnits.startIndex,
      to: oldPrefix
    )
    let replacement = String(
      decoding: newUnits[newPrefix..<newSuffix],
      as: UTF16.self
    )

    return Self(
      range: UTF16Range(
        location: location,
        length: oldUnits.distance(from: oldPrefix, to: oldSuffix)
      ),
      replacement: replacement
    )
  }
}

extension String.UTF16View {
  /// Returns whether an index falls between complete Unicode scalars.
  ///
  /// - Parameter index: The UTF-16 index whose boundary should be checked.
  /// - Returns: `false` only when the index splits a surrogate pair.
  fileprivate func isScalarBoundary(at index: Index) -> Bool {
    guard index != startIndex, index != endIndex else {
      return true
    }

    return
      !(self[self.index(before: index)].isHighSurrogate
      && self[index].isLowSurrogate)
  }
}

extension UInt16 {
  /// Returns whether this code unit begins a UTF-16 surrogate pair.
  fileprivate var isHighSurrogate: Bool {
    (0xD800...0xDBFF).contains(self)
  }

  /// Returns whether this code unit ends a UTF-16 surrogate pair.
  fileprivate var isLowSurrogate: Bool {
    (0xDC00...0xDFFF).contains(self)
  }
}
