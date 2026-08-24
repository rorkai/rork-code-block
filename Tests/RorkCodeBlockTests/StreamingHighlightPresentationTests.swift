import RorkHighlighter
import Testing

@testable import RorkCodeBlock

/// Verifies the stability-driven presentation used while streaming.
@Suite("Streaming highlight presentation")
struct StreamingHighlightPresentationTests {
  /// Verifies that captures beyond the stability boundary stay neutral.
  @Test("Withholds captures beyond the stability boundary")
  func withholdsCapturesBeyondStabilityBoundary() {
    let presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "let value = 42",
        language: .swift,
        revision: 0,
        highlights: [
          HighlightSpan(scope: "keyword", range: UTF16Range(0..<3)),
          HighlightSpan(scope: "number", range: UTF16Range(12..<14)),
        ],
        stableUTF16Length: 12
      ),
      theme: .rorkDark
    )

    #expect(
      presentation.snapshot.highlights == [
        HighlightSpan(scope: "keyword", range: UTF16Range(0..<3))
      ]
    )
  }

  /// Verifies that a capture straddling the boundary is partially revealed.
  @Test("Clips a capture that straddles the boundary")
  func clipsCaptureStraddlingBoundary() {
    let presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "let greeting = \"Hello",
        language: .swift,
        revision: 0,
        highlights: [
          HighlightSpan(scope: "string", range: UTF16Range(15..<21))
        ],
        stableUTF16Length: 16
      ),
      theme: .rorkDark
    )

    #expect(
      presentation.snapshot.highlights == [
        HighlightSpan(scope: "string", range: UTF16Range(15..<16))
      ]
    )
  }

  /// Verifies that newly settled syntax is revealed by an append.
  @Test("Reveals newly settled captures after an append")
  func revealsNewlySettledCapturesAfterAppend() {
    let presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "let value = 42",
        language: .swift,
        revision: 0,
        highlights: [
          HighlightSpan(scope: "keyword", range: UTF16Range(0..<3)),
          HighlightSpan(scope: "number", range: UTF16Range(12..<14)),
        ],
        stableUTF16Length: 12
      ),
      theme: .rorkDark
    )

    let (update, advanced) = presentation.applying(
      HighlightUpdate(
        replacedRange: UTF16Range(location: 14, length: 0),
        replacementRange: UTF16Range(location: 14, length: 1),
        invalidatedRanges: [],
        snapshot: HighlightSnapshot(
          text: "let value = 42\n",
          language: .swift,
          revision: 1,
          highlights: [
            HighlightSpan(scope: "keyword", range: UTF16Range(0..<3)),
            HighlightSpan(scope: "number", range: UTF16Range(12..<14)),
          ],
          stableUTF16Length: 15
        )
      ),
      theme: .rorkDark
    )

    #expect(
      advanced.snapshot.highlights == [
        HighlightSpan(scope: "keyword", range: UTF16Range(0..<3)),
        HighlightSpan(scope: "number", range: UTF16Range(12..<14)),
      ]
    )
    #expect(update.invalidatedRanges == [UTF16Range(12..<14)])
  }

  /// Verifies that a recovery dip keeps previously revealed styles.
  ///
  /// When appended input drags settled syntax back into Tree-sitter's error
  /// recovery, the parser temporarily reports different captures for source
  /// that was already revealed. The presentation must keep the last settled
  /// styles instead of following the recovery guesses, and it must report no
  /// visible change.
  @Test("Freezes revealed styles during a recovery dip")
  func freezesRevealedStylesDuringRecoveryDip() {
    let presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "struct Reply: View {\n",
        language: .swift,
        revision: 0,
        highlights: [
          HighlightSpan(scope: "keyword.type", range: UTF16Range(0..<6)),
          HighlightSpan(scope: "type", range: UTF16Range(7..<12)),
          HighlightSpan(scope: "type", range: UTF16Range(14..<18)),
        ],
        stableUTF16Length: 21
      ),
      theme: .rorkDark
    )

    // The appended generic drags the whole declaration into an error node.
    // The exact snapshot now reports no captures for the header and a
    // stability boundary of zero.
    let (update, dipped) = presentation.applying(
      HighlightUpdate(
        replacedRange: UTF16Range(location: 21, length: 0),
        replacementRange: UTF16Range(location: 21, length: 12),
        invalidatedRanges: [UTF16Range(0..<33)],
        snapshot: HighlightSnapshot(
          text: "struct Reply: View {\nlet x: A<Str",
          language: .swift,
          revision: 1,
          highlights: [],
          stableUTF16Length: 0
        )
      ),
      theme: .rorkDark
    )

    #expect(
      dipped.snapshot.highlights == presentation.snapshot.highlights
    )
    #expect(update.invalidatedRanges.isEmpty)
  }

  /// Verifies that the dip zone resynchronizes once syntax settles again.
  ///
  /// The sawtooth between error recovery and missing-token recovery must
  /// produce no visible change when the settled classifications return, so
  /// streaming stays flicker free.
  @Test("Resynchronizes the dip zone without visible changes")
  func resynchronizesDipZoneWithoutVisibleChanges() {
    let initial = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "struct Reply: View {\n",
        language: .swift,
        revision: 0,
        highlights: [
          HighlightSpan(scope: "keyword.type", range: UTF16Range(0..<6)),
          HighlightSpan(scope: "type", range: UTF16Range(7..<12)),
        ],
        stableUTF16Length: 21
      ),
      theme: .rorkDark
    )

    let (_, dipped) = initial.applying(
      HighlightUpdate(
        replacedRange: UTF16Range(location: 21, length: 0),
        replacementRange: UTF16Range(location: 21, length: 8),
        invalidatedRanges: [UTF16Range(0..<29)],
        snapshot: HighlightSnapshot(
          text: "struct Reply: View {\nlet x: A",
          language: .swift,
          revision: 1,
          highlights: [],
          stableUTF16Length: 0
        )
      ),
      theme: .rorkDark
    )

    // The next chunk completes the property and recovery settles again with
    // the original classifications.
    let (update, settled) = dipped.applying(
      HighlightUpdate(
        replacedRange: UTF16Range(location: 29, length: 0),
        replacementRange: UTF16Range(location: 29, length: 6),
        invalidatedRanges: [UTF16Range(0..<35)],
        snapshot: HighlightSnapshot(
          text: "struct Reply: View {\nlet x: Array\n",
          language: .swift,
          revision: 2,
          highlights: [
            HighlightSpan(scope: "keyword.type", range: UTF16Range(0..<6)),
            HighlightSpan(scope: "type", range: UTF16Range(7..<12)),
            HighlightSpan(scope: "keyword", range: UTF16Range(21..<24)),
            HighlightSpan(scope: "type", range: UTF16Range(28..<33)),
          ],
          stableUTF16Length: 34
        )
      ),
      theme: .rorkDark
    )

    #expect(
      settled.snapshot.highlights == [
        HighlightSpan(scope: "keyword.type", range: UTF16Range(0..<6)),
        HighlightSpan(scope: "type", range: UTF16Range(7..<12)),
        HighlightSpan(scope: "keyword", range: UTF16Range(21..<24)),
        HighlightSpan(scope: "type", range: UTF16Range(28..<33)),
      ]
    )

    // Only the newly revealed spans repaint. The previously revealed header
    // spans stay untouched across the whole sawtooth.
    #expect(
      update.invalidatedRanges == [
        UTF16Range(21..<24),
        UTF16Range(28..<33),
      ]
    )
  }

  /// Verifies that settled syntax follows exact reclassification.
  ///
  /// Some grammars reinterpret settled syntax without reporting recovery,
  /// for example Markdown emphasis when its closing delimiter arrives. The
  /// settled zone must follow the exact captures so the stream converges to
  /// the final rendering.
  @Test("Follows exact reclassification inside the settled zone")
  func followsExactReclassificationInsideSettledZone() {
    let presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "Some **bold te",
        language: .markdown,
        revision: 0,
        highlights: [],
        stableUTF16Length: 14
      ),
      theme: .rorkDark
    )

    let (update, advanced) = presentation.applying(
      HighlightUpdate(
        replacedRange: UTF16Range(location: 14, length: 0),
        replacementRange: UTF16Range(location: 14, length: 4),
        invalidatedRanges: [UTF16Range(5..<18)],
        snapshot: HighlightSnapshot(
          text: "Some **bold te**\n\n",
          language: .markdown,
          revision: 1,
          highlights: [
            HighlightSpan(scope: "text.strong", range: UTF16Range(5..<16))
          ],
          stableUTF16Length: 18
        )
      ),
      theme: .rorkDark
    )

    #expect(
      advanced.snapshot.highlights == [
        HighlightSpan(scope: "text.strong", range: UTF16Range(5..<16))
      ]
    )
    #expect(update.invalidatedRanges == [UTF16Range(5..<16)])
  }

  /// Verifies that a non-append edit rebuilds and repaints everything.
  @Test("Rebuilds after a non-append replacement")
  func rebuildsAfterNonAppendReplacement() {
    let presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "let value = 42",
        language: .swift,
        revision: 0,
        highlights: [
          HighlightSpan(scope: "keyword", range: UTF16Range(0..<3))
        ],
        stableUTF16Length: 12
      ),
      theme: .rorkDark
    )

    let (update, replaced) = presentation.applying(
      HighlightUpdate(
        replacedRange: UTF16Range(location: 4, length: 5),
        replacementRange: UTF16Range(location: 4, length: 4),
        invalidatedRanges: [UTF16Range(4..<8)],
        snapshot: HighlightSnapshot(
          text: "let name = 42",
          language: .swift,
          revision: 1,
          highlights: [
            HighlightSpan(scope: "keyword", range: UTF16Range(0..<3)),
            HighlightSpan(scope: "number", range: UTF16Range(11..<13)),
          ],
          stableUTF16Length: 11
        )
      ),
      theme: .rorkDark
    )

    #expect(
      replaced.snapshot.highlights == [
        HighlightSpan(scope: "keyword", range: UTF16Range(0..<3))
      ]
    )
    #expect(update.invalidatedRanges == [UTF16Range(0..<13)])
  }

  /// Verifies that a surviving classification is revealed after enough
  /// appended input.
  ///
  /// A construct held inside end-of-input recovery, such as a call with a
  /// streaming trailing closure, can keep one classification across many
  /// revisions while the stability boundary sits before it. Outliving 42
  /// UTF-16 units of appended source reveals it so the construct does not
  /// stay neutral until its closing braces arrive.
  @Test("Reveals a classification that outlives appended input")
  func revealsClassificationThatOutlivesAppendedInput() {
    let callSpan = HighlightSpan(
      scope: "function.call",
      range: UTF16Range(10..<19)
    )
    var presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "let x = a(CodeBlock(source",
        language: .swift,
        revision: 0,
        highlights: [callSpan],
        stableUTF16Length: 0
      ),
      theme: .rorkDark
    )

    // Each revision appends seven units, so the span has outlived 42 units
    // of input at the sixth revision.
    for revision in 1...6 {
      let text =
        "let x = a(CodeBlock(source"
        + String(
          repeating: ", chunk",
          count: revision
        )
      let previousLength = text.utf16.count - 7
      let (update, advanced) = presentation.applying(
        HighlightUpdate(
          replacedRange: UTF16Range(location: previousLength, length: 0),
          replacementRange: UTF16Range(
            location: previousLength,
            length: 7
          ),
          invalidatedRanges: [],
          snapshot: HighlightSnapshot(
            text: text,
            language: .swift,
            revision: UInt64(revision),
            highlights: [callSpan],
            stableUTF16Length: 0
          )
        ),
        theme: .rorkDark
      )
      presentation = advanced

      if revision < 6 {
        #expect(advanced.snapshot.highlights.isEmpty)
        #expect(update.invalidatedRanges.isEmpty)
      } else {
        #expect(advanced.snapshot.highlights == [callSpan])
        #expect(update.invalidatedRanges == [callSpan.range])
      }
    }
  }

  /// Verifies that large chunks confirm without extra observations.
  ///
  /// Survival is measured against appended source rather than parser
  /// samples, so one large chunk provides the same evidence as many small
  /// ones and streams with coarse chunks reveal without artificial delay.
  @Test("Confirms a classification after one large append")
  func confirmsClassificationAfterOneLargeAppend() {
    let callSpan = HighlightSpan(
      scope: "function.call",
      range: UTF16Range(10..<19)
    )
    let presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "let x = a(CodeBlock(source",
        language: .swift,
        revision: 0,
        highlights: [callSpan],
        stableUTF16Length: 0
      ),
      theme: .rorkDark
    )

    let appended = String(repeating: ",x", count: 21)
    let text = "let x = a(CodeBlock(source" + appended
    let previousLength = text.utf16.count - appended.utf16.count
    let (update, advanced) = presentation.applying(
      HighlightUpdate(
        replacedRange: UTF16Range(location: previousLength, length: 0),
        replacementRange: UTF16Range(
          location: previousLength,
          length: appended.utf16.count
        ),
        invalidatedRanges: [],
        snapshot: HighlightSnapshot(
          text: text,
          language: .swift,
          revision: 1,
          highlights: [callSpan],
          stableUTF16Length: 0
        )
      ),
      theme: .rorkDark
    )

    #expect(advanced.snapshot.highlights == [callSpan])
    #expect(update.invalidatedRanges == [callSpan.range])
  }

  /// Verifies that a changed classification restarts its survival.
  ///
  /// Recovery guesses die within a short stretch of input, so a span whose
  /// classification flips never accumulates enough survival to reveal,
  /// even when each observation is separated by a large append.
  @Test("Keeps alternating classifications hidden")
  func keepsAlternatingClassificationsHidden() {
    var presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "person.name",
        language: .swift,
        revision: 0,
        highlights: [
          HighlightSpan(scope: "type", range: UTF16Range(0..<6))
        ],
        stableUTF16Length: 0
      ),
      theme: .rorkDark
    )

    // Each revision appends 28 units, enough to confirm within two
    // observations if the alternation failed to restart survival.
    for revision in 1...8 {
      let text = "person.name" + String(
        repeating: ".",
        count: 28 * revision
      )
      let previousLength = text.utf16.count - 28
      let scope = revision.isMultiple(of: 2) ? "type" : "variable.member"
      let (update, advanced) = presentation.applying(
        HighlightUpdate(
          replacedRange: UTF16Range(location: previousLength, length: 0),
          replacementRange: UTF16Range(
            location: previousLength,
            length: 28
          ),
          invalidatedRanges: [],
          snapshot: HighlightSnapshot(
            text: text,
            language: .swift,
            revision: UInt64(revision),
            highlights: [
              HighlightSpan(scope: scope, range: UTF16Range(0..<6))
            ],
            stableUTF16Length: 0
          )
        ),
        theme: .rorkDark
      )
      presentation = advanced

      #expect(advanced.snapshot.highlights.isEmpty)
      #expect(update.invalidatedRanges.isEmpty)
    }
  }

  /// Verifies that revealed styles outrank later confirmations.
  ///
  /// A style revealed while the syntax was settled stays authoritative
  /// through a recovery dip, even when the parser's current guess has
  /// outlived enough input to confirm, because recoloring revealed source
  /// is flicker.
  @Test("Prefers revealed styles over later confirmations")
  func prefersRevealedStylesOverLaterConfirmations() {
    let revealedSpan = HighlightSpan(
      scope: "type",
      range: UTF16Range(0..<6)
    )
    var presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "Person",
        language: .swift,
        revision: 0,
        highlights: [revealedSpan],
        stableUTF16Length: 6
      ),
      theme: .rorkDark
    )

    // Each revision appends 45 units, so the conflicting keyword guess is
    // confirmed from the second observation onward and must still lose.
    for revision in 1...4 {
      let text = "Person" + String(
        repeating: "?",
        count: 45 * revision
      )
      let previousLength = text.utf16.count - 45
      let (_, advanced) = presentation.applying(
        HighlightUpdate(
          replacedRange: UTF16Range(location: previousLength, length: 0),
          replacementRange: UTF16Range(
            location: previousLength,
            length: 45
          ),
          invalidatedRanges: [],
          snapshot: HighlightSnapshot(
            text: text,
            language: .swift,
            revision: UInt64(revision),
            highlights: [
              HighlightSpan(scope: "keyword", range: UTF16Range(0..<6))
            ],
            stableUTF16Length: 0
          )
        ),
        theme: .rorkDark
      )
      presentation = advanced

      #expect(advanced.snapshot.highlights == [revealedSpan])
    }
  }

  /// Verifies that unknown stability reveals every exact capture.
  ///
  /// Hand-built snapshots without parse information behave like exact
  /// non-streaming rendering.
  @Test("Reveals everything when stability is unknown")
  func revealsEverythingWhenStabilityIsUnknown() {
    let presentation = StreamingHighlightPresentation(
      snapshot: HighlightSnapshot(
        text: "let value = 42",
        language: .swift,
        revision: 0,
        highlights: [
          HighlightSpan(scope: "keyword", range: UTF16Range(0..<3)),
          HighlightSpan(scope: "number", range: UTF16Range(12..<14)),
        ]
      ),
      theme: .rorkDark
    )

    #expect(presentation.snapshot.highlights.count == 2)
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
