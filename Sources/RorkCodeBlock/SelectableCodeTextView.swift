import UIKit

/// Presents selectable source on an explicitly constructed TextKit 2 stack.
///
/// Unwrapped source expands the text container to its widest logical line and
/// scrolls horizontally. Wrapped source tracks the viewport width. The SwiftUI
/// wrapper supplies the full content height, so vertical scrolling remains off.
final class SelectableCodeTextView: UITextView {
  /// Holds how source lines wider than the viewport should be presented.
  var lineWrapping = CodeLineWrapping.disabled {
    didSet {
      guard oldValue != lineWrapping else {
        return
      }

      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }

  /// Holds the measured width required by the widest logical source line.
  var widestLineWidth: CGFloat = 1 {
    didSet {
      guard oldValue.differs(from: widestLineWidth) else {
        return
      }

      setNeedsLayout()
    }
  }

  /// Retains the root of the explicitly assembled TextKit 2 object graph.
  private let codeContentStorage: NSTextContentStorage

  /// Retains the layout manager used for fitting and viewport layout.
  private let codeLayoutManager: NSTextLayoutManager

  /// Retains the text container whose width follows wrapping behavior.
  private let codeTextContainer: NSTextContainer

  /// Prevents geometry synchronization from re-entering `layoutSubviews()`.
  private var isSynchronizingGeometry = false

  /// Creates a selectable text view backed by an explicit TextKit 2 stack.
  init() {
    let contentStorage = NSTextContentStorage()
    let layoutManager = NSTextLayoutManager()
    let textContainer = NSTextContainer(
      size: CGSize(width: 1, height: Metrics.unboundedHeight)
    )

    contentStorage.addTextLayoutManager(layoutManager)
    layoutManager.textContainer = textContainer

    codeContentStorage = contentStorage
    codeLayoutManager = layoutManager
    codeTextContainer = textContainer

    super.init(frame: .zero, textContainer: textContainer)

    // iOS 26 derives scroll padding from this view's corner geometry. The
    // SwiftUI card owns the visible rounding, so square UIKit geometry keeps
    // the indicator inset stable wherever the block appears. The compiler
    // guard preserves Xcode 16 compatibility because its SDK lacks this API.
    #if compiler(>=6.2)
      if #available(iOS 26.0, visionOS 26.0, *) {
        cornerConfiguration = .uniformCorners(radius: 0)
      }
    #endif

    codeTextContainer.lineFragmentPadding = 0

    assert(
      textLayoutManager === codeLayoutManager,
      "The code text view must remain on TextKit 2."
    )
  }

  /// Prevents construction through Interface Builder archives.
  ///
  /// - Parameter coder: The unsupported archive decoder.
  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  /// Synchronizes TextKit container and scroll geometry during UIKit layout.
  override func layoutSubviews() {
    guard !isSynchronizingGeometry else {
      super.layoutSubviews()
      return
    }

    isSynchronizingGeometry = true
    defer { isSynchronizingGeometry = false }

    updateContainerGeometry(forWidth: bounds.width)
    super.layoutSubviews()
    updateScrollGeometry()
  }

  /// Returns the height required to display the complete source at a width.
  ///
  /// - Parameter width: The viewport width proposed by SwiftUI.
  /// - Returns: The fitted TextKit height including text container insets.
  func height(fittingWidth width: CGFloat) -> CGFloat {
    updateContainerGeometry(forWidth: width)
    codeLayoutManager.ensureLayout(for: codeLayoutManager.documentRange)

    return ceil(
      codeLayoutManager.usageBoundsForTextContainer.height
        + textContainerInset.top
        + textContainerInset.bottom
    )
  }

  /// Restores and clamps a previously saved horizontal content offset.
  ///
  /// - Parameter offset: The offset captured before a text or style update.
  func restoreContentOffset(_ offset: CGPoint) {
    setContentOffset(offset, animated: false)
    clampContentOffset()
  }

  /// Scrolls to the physical left edge where source text begins.
  func scrollToLeadingEdge() {
    setContentOffset(
      CGPoint(
        x: -adjustedContentInset.left,
        y: -adjustedContentInset.top
      ),
      animated: false
    )
  }

  /// Sizes the TextKit container for wrapping or horizontal scrolling.
  ///
  /// - Parameter width: The current UIKit viewport width.
  private func updateContainerGeometry(forWidth width: CGFloat) {
    codeTextContainer.widthTracksTextView = false
    codeTextContainer.heightTracksTextView = false
    codeTextContainer.lineBreakMode = lineWrapping.lineBreakMode

    let viewportWidth = max(1, width - textContainerInset.horizontal)
    let containerWidth =
      switch lineWrapping {
      case .disabled:
        max(viewportWidth, widestLineWidth)
      case .enabled:
        viewportWidth
      }
    let size = CGSize(
      width: containerWidth,
      height: Metrics.unboundedHeight
    )

    guard codeTextContainer.size.differs(from: size) else {
      return
    }

    codeTextContainer.size = size
  }

  /// Pins vertical scrolling and exposes the complete unwrapped content width.
  private func updateScrollGeometry() {
    guard bounds.width > 0, bounds.height > 0 else {
      return
    }

    let contentWidth =
      switch lineWrapping {
      case .disabled:
        ceil(
          max(
            bounds.width,
            codeTextContainer.size.width + textContainerInset.horizontal
          )
        )
      case .enabled:
        bounds.width
      }
    let size = CGSize(width: contentWidth, height: bounds.height)

    if contentSize.differs(from: size) {
      contentSize = size
    }

    clampContentOffset()
  }

  /// Keeps the content offset inside the current horizontal geometry.
  private func clampContentOffset() {
    guard !isTracking, !isDragging, !isDecelerating else {
      return
    }

    let minimumX = -adjustedContentInset.left
    let maximumX = max(
      minimumX,
      contentSize.width - bounds.width + adjustedContentInset.right
    )
    let targetX =
      switch lineWrapping {
      case .disabled:
        min(max(contentOffset.x, minimumX), maximumX)
      case .enabled:
        minimumX
      }
    let targetY = -adjustedContentInset.top

    guard
      contentOffset.x.differs(from: targetX)
        || contentOffset.y.differs(from: targetY)
    else {
      return
    }

    contentOffset = CGPoint(x: targetX, y: targetY)
  }

  /// Stores the practical unbounded height used by the TextKit container.
  private enum Metrics {
    /// Prevents vertical fragmentation while remaining inside finite geometry.
    static let unboundedHeight: CGFloat = 10_000_000
  }
}

/// Defines the smallest geometry change worth another layout pass.
private let geometryTolerance: CGFloat = 0.5

extension CGFloat {
  /// Returns whether another value differs by more than the layout tolerance.
  ///
  /// - Parameter other: The geometry value to compare.
  /// - Returns: `true` when the difference can affect visible layout.
  fileprivate func differs(from other: CGFloat) -> Bool {
    abs(self - other) > geometryTolerance
  }
}

extension CGSize {
  /// Returns whether either dimension differs by more than the layout tolerance.
  ///
  /// - Parameter other: The size to compare.
  /// - Returns: `true` when either difference can affect visible layout.
  fileprivate func differs(from other: CGSize) -> Bool {
    width.differs(from: other.width) || height.differs(from: other.height)
  }
}

extension UIEdgeInsets {
  /// Returns the combined physical left and right insets.
  fileprivate var horizontal: CGFloat {
    left + right
  }
}

extension NSRange {
  /// Restricts a selection to a source string of a given UTF-16 length.
  ///
  /// - Parameter length: The nonnegative UTF-16 source length.
  /// - Returns: A range whose location and length stay inside the source.
  func clamped(toLength length: Int) -> NSRange {
    let start = min(location, length)
    return NSRange(
      location: start,
      length: min(self.length, length - start)
    )
  }

  /// Moves a selection through one UTF-16 source replacement.
  ///
  /// - Parameters:
  ///   - edit: The replacement applied to the previous source.
  ///   - resultingLength: The UTF-16 length after applying the replacement.
  /// - Returns: The transformed selection clamped to the resulting source.
  func applying(
    _ edit: SourceEdit,
    resultingLength: Int
  ) -> NSRange {
    let editStart = edit.range.location
    let editEnd = edit.range.location + edit.range.length
    let replacementEnd = editStart + edit.replacementRange.length
    let lengthDelta = edit.replacementRange.length - edit.range.length

    /// Maps one selection boundary through the replacement.
    ///
    /// - Parameter position: The UTF-16 boundary in the previous source.
    /// - Returns: The corresponding boundary in the resulting source.
    func transformed(_ position: Int) -> Int {
      if position < editStart {
        return position
      }

      if position > editEnd || edit.range.length == 0 {
        return position + lengthDelta
      }

      return replacementEnd
    }

    let start = transformed(location)
    let end = transformed(location + length)

    return NSRange(
      location: min(start, end),
      length: abs(end - start)
    ).clamped(toLength: resultingLength)
  }
}
