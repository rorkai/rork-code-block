import Observation

/// Drives the deterministic source stream shown by the example app.
@MainActor
@Observable
final class StreamingExampleModel {
  /// Holds the source revision currently visible in the code block.
  private(set) var source: String

  /// Reports whether the selected fixture is still being emitted.
  private(set) var isStreaming = false

  /// Holds the active replay operation without making it observable state.
  @ObservationIgnored private var streamingTask: Task<Void, Never>?

  /// Identifies the latest replay so cancelled work cannot finish a newer run.
  @ObservationIgnored private var generation = 0

  /// Creates a model showing one complete source fixture.
  ///
  /// - Parameter source: The complete source shown before the first replay.
  init(source: String) {
    self.source = source
  }

  /// Cancels unfinished work when the example model leaves memory.
  deinit {
    streamingTask?.cancel()
  }

  /// Presents a complete fixture without simulating a stream.
  ///
  /// - Parameter source: The complete source to show immediately.
  func present(_ source: String) {
    generation += 1
    streamingTask?.cancel()
    streamingTask = nil
    isStreaming = false
    self.source = source
  }

  /// Replays a complete fixture as a rapid sequence of small source updates.
  ///
  /// - Parameter source: The complete source produced by the replay.
  func replay(_ source: String) {
    generation += 1
    let replayGeneration = generation
    let chunks = Self.chunks(of: source)

    streamingTask?.cancel()
    self.source = ""
    isStreaming = true

    streamingTask = Task { [weak self] in
      let clock = ContinuousClock()

      for chunk in chunks {
        guard
          let self,
          generation == replayGeneration,
          !Task.isCancelled
        else {
          return
        }

        self.source += chunk

        do {
          try await clock.sleep(for: Metrics.chunkInterval)
        } catch {
          return
        }
      }

      guard let self, generation == replayGeneration else {
        return
      }

      isStreaming = false
      streamingTask = nil
    }
  }

  /// Divides source at character boundaries for deterministic replay updates.
  ///
  /// - Parameter source: The complete source to divide.
  /// - Returns: Consecutive chunks that reconstruct the original source.
  nonisolated private static func chunks(of source: String) -> [String] {
    var chunks: [String] = []
    var start = source.startIndex

    while start < source.endIndex {
      let end =
        source.index(
          start,
          offsetBy: Metrics.charactersPerChunk,
          limitedBy: source.endIndex
        ) ?? source.endIndex

      chunks.append(String(source[start..<end]))
      start = end
    }

    return chunks
  }

  /// Stores the fixed replay cadence used by the example.
  private enum Metrics {
    /// Keeps each update large enough to finish a replay promptly.
    static let charactersPerChunk = 7

    /// Produces source updates slightly faster than one display frame.
    static let chunkInterval = Duration.milliseconds(12)
  }
}
