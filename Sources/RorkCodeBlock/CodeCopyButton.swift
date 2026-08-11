import SwiftUI
import UIKit

/// Copies a code block's complete source and briefly confirms the action.
struct CodeCopyButton: View {
  /// Holds the source written to the system pasteboard.
  let source: String

  /// Tracks whether the confirmation symbol is currently visible.
  @State private var didCopy = false

  /// Changes after each copy so repeated actions produce fresh feedback.
  @State private var copyCount = 0

  /// Retains the task that clears the confirmation symbol.
  @State private var resetTask: Task<Void, Never>?

  /// Returns the accessible copy button.
  var body: some View {
    buttonWithFeedback
      .onDisappear(perform: cancelReset)
  }

  /// Returns the copy button with feedback supported by its current platform.
  @ViewBuilder
  private var buttonWithFeedback: some View {
    #if os(visionOS)
      button
    #else
      button.sensoryFeedback(.success, trigger: copyCount)
    #endif
  }

  /// Returns the copy control without platform-specific sensory feedback.
  private var button: some View {
    Button(action: copySource) {
      Image(systemName: didCopy ? "checkmark" : "square.on.square")
        .font(.system(size: Metrics.symbolSize, weight: .medium))
        .frame(width: Metrics.tapTargetSize, height: Metrics.tapTargetSize)
        .contentTransition(.identity)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(didCopy ? "Code copied" : "Copy code")
    .accessibilityHint("Copies the complete source to the clipboard")
  }

  /// Writes the source to the pasteboard and starts a confirmation interval.
  private func copySource() {
    UIPasteboard.general.string = source
    setDidCopy(true)
    copyCount += 1

    resetTask?.cancel()
    resetTask = Task {
      try? await Task.sleep(for: Metrics.confirmationDuration)

      guard !Task.isCancelled else {
        return
      }

      setDidCopy(false)
    }
  }

  /// Changes the confirmation state without inheriting an enclosing animation.
  ///
  /// - Parameter newValue: Whether the confirmation symbol should be visible.
  private func setDidCopy(_ newValue: Bool) {
    withTransaction(Transaction(animation: nil)) {
      didCopy = newValue
    }
  }

  /// Cancels delayed state changes after SwiftUI removes the control.
  private func cancelReset() {
    resetTask?.cancel()
    resetTask = nil
  }

  /// Stores the fixed feedback and control measurements.
  private enum Metrics {
    /// Keeps the confirmation visible long enough to be recognized.
    static let confirmationDuration = Duration.seconds(2.5)

    /// Matches the copy symbol to compact system controls.
    static let symbolSize: CGFloat = 17

    /// Provides a comfortable target without enlarging the visible symbol.
    static let tapTargetSize: CGFloat = 32
  }
}
