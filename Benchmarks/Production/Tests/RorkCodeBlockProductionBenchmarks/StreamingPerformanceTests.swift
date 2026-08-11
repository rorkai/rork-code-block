import Dispatch
@_spi(Benchmarking) import RorkCodeBlock
import UIKit
import XCTest
import os.lock

/// Measures the incremental work owned by the code block package.
final class StreamingPerformanceTests: XCTestCase {
  /// Measures repeated fixed-width revisions after warming the parser session.
  func testIncrementalStreamingPerformance() throws {
    let highlighter = StreamingHighlighter()
    let firstSource = Self.source(revision: 0)
    let secondSource = Self.source(revision: 1)

    try Self.waitForAsync {
      _ = try await highlighter.highlight(firstSource, as: .swift)
    }

    var usesSecondSource = true

    measure(metrics: [XCTClockMetric()]) {
      let source = usesSecondSource ? secondSource : firstSource

      do {
        try Self.waitForAsync {
          _ = try await highlighter.highlight(source, as: .swift)
        }
      } catch {
        XCTFail("Incremental highlighting failed with \(error)")
      }

      usesSecondSource.toggle()
    }
  }

  /// Measures incremental line sizing after one fixed-width source edit.
  @MainActor
  func testIncrementalLineWidthPerformance() throws {
    let firstSource = Self.source(revision: 0)
    let secondSource = Self.source(revision: 1)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    ]
    let attributedSource = NSMutableAttributedString(
      string: firstSource,
      attributes: attributes
    )
    var cache = CodeLineWidthCache()
    cache.rebuild(from: attributedSource)

    guard
      let forwardEdit = SourceEdit.difference(
        from: firstSource,
        to: secondSource
      ),
      let reverseEdit = SourceEdit.difference(
        from: secondSource,
        to: firstSource
      )
    else {
      XCTFail("The benchmark revisions must differ")
      return
    }

    var usesSecondSource = true

    measure(metrics: [XCTClockMetric()]) {
      for _ in 0..<Fixture.lineWidthIterationCount {
        let edit = usesSecondSource ? forwardEdit : reverseEdit
        attributedSource.replaceCharacters(
          in: NSRange(
            location: edit.range.location,
            length: edit.range.length
          ),
          with: NSAttributedString(
            string: edit.replacement,
            attributes: attributes
          )
        )
        cache.update(after: edit, in: attributedSource)
        usesSecondSource.toggle()
      }
    }

    XCTAssertGreaterThan(cache.widestLineWidth, 0)
  }

  /// Builds a deterministic Swift document with one changing tail marker.
  ///
  /// - Parameter revision: The fixed-width value written to the final line.
  /// - Returns: A representative source document for one revision.
  private static func source(revision: Int) -> String {
    let declarations = (0..<Fixture.declarationCount)
      .map { index in
        "let value\(index) = \(index)"
      }
      .joined(separator: "\n")

    return declarations + "\nlet revision = \(revision)\n"
  }

  /// Runs one actor operation to completion from XCTest's synchronous metric block.
  ///
  /// - Parameter operation: The asynchronous highlighting work to perform.
  /// - Throws: The typed highlighting error produced by the operation.
  private static func waitForAsync(
    _ operation: @escaping @Sendable () async throws -> Void
  ) throws(BenchmarkFailure) {
    let completion = DispatchSemaphore(value: 0)
    let storedResult = OSAllocatedUnfairLock<
      Result<Void, BenchmarkFailure>?
    >(initialState: nil)

    Task.detached {
      let result: Result<Void, BenchmarkFailure>

      do {
        try await operation()
        result = .success(())
      } catch {
        result = .failure(BenchmarkFailure(error: error))
      }

      storedResult.withLock { value in
        value = result
      }
      completion.signal()
    }

    completion.wait()

    guard let result = storedResult.withLock({ $0 }) else {
      preconditionFailure("The benchmark operation completed without a result.")
    }

    try result.get()
  }

  /// Stores the deterministic scale used by the component benchmark.
  private enum Fixture {
    /// Keeps the fixture large enough to expose source-diff and parser overhead.
    static let declarationCount = 500

    /// Batches tiny line updates so timer noise does not dominate the result.
    static let lineWidthIterationCount = 1_000
  }

  /// Preserves an asynchronous benchmark failure across the synchronous bridge.
  private struct BenchmarkFailure: Error, Sendable, CustomStringConvertible {
    /// Holds the readable description of the original failure.
    let description: String

    /// Creates a sendable failure from an arbitrary operation error.
    ///
    /// - Parameter error: The asynchronous error that stopped the benchmark.
    init(error: any Error) {
      description = String(describing: error)
    }
  }
}
