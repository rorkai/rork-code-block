import Dispatch
import XCTest
import os.lock

@testable import RorkCodeBlock

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
