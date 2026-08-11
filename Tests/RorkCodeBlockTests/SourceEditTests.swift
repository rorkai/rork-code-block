import Foundation
import Testing

@testable @_spi(Benchmarking) import RorkCodeBlock

/// Verifies the UTF-16 edit calculation used by streaming updates.
@Suite("Source edits")
struct SourceEditTests {
  /// Verifies that ordinary streaming appends produce an empty replacement range.
  @Test("Calculates an append")
  func calculatesAppend() {
    let edit = SourceEdit.difference(
      from: "let greeting = ",
      to: "let greeting = \"Hello\""
    )

    #expect(
      edit
        == SourceEdit(
          range: .init(location: 15, length: 0),
          replacement: "\"Hello\""
        )
    )
  }

  /// Verifies that unchanged prefixes and suffixes stay outside a replacement.
  @Test("Calculates a middle replacement")
  func calculatesMiddleReplacement() {
    let edit = SourceEdit.difference(
      from: "print(\"Hello\")",
      to: "print(\"Rork\")"
    )

    #expect(
      edit
        == SourceEdit(
          range: .init(location: 7, length: 5),
          replacement: "Rork"
        )
    )
  }

  /// Verifies that removing source produces an empty replacement string.
  @Test("Calculates a deletion")
  func calculatesDeletion() {
    let edit = SourceEdit.difference(
      from: "let value = 42",
      to: "let value = "
    )

    #expect(
      edit
        == SourceEdit(
          range: .init(location: 12, length: 2),
          replacement: ""
        )
    )
  }

  /// Verifies that a shared high surrogate is not mistaken for a valid boundary.
  @Test("Keeps Unicode scalar boundaries")
  func keepsUnicodeScalarBoundaries() {
    let edit = SourceEdit.difference(from: "😀", to: "😁")

    #expect(
      edit
        == SourceEdit(
          range: .init(location: 0, length: 2),
          replacement: "😁"
        )
    )
  }

  /// Verifies that identical source revisions produce no work.
  @Test("Skips identical source")
  func skipsIdenticalSource() {
    #expect(SourceEdit.difference(from: "let value = 42", to: "let value = 42") == nil)
  }

  /// Verifies that a selection after an insertion follows its original text.
  @Test("Moves a selection through an insertion")
  func movesSelectionThroughInsertion() {
    let edit = SourceEdit(
      range: .init(location: 0, length: 0),
      replacement: "// "
    )
    let selection = NSRange(location: 4, length: 5)

    #expect(
      selection.applying(edit, resultingLength: 12)
        == NSRange(location: 7, length: 5)
    )
  }

  /// Verifies that replacing selected source collapses at the replacement end.
  @Test("Moves an overlapping selection through a replacement")
  func movesOverlappingSelectionThroughReplacement() {
    let edit = SourceEdit(
      range: .init(location: 7, length: 5),
      replacement: "Rork"
    )
    let selection = NSRange(location: 7, length: 5)

    #expect(
      selection.applying(edit, resultingLength: 13)
        == NSRange(location: 11, length: 0)
    )
  }
}
