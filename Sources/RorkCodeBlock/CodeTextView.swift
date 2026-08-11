import RorkHighlighter
import SwiftUI
import UIKit

/// Bridges the selectable TextKit view used to present source code.
struct CodeTextView: UIViewRepresentable {
  /// Identifies the UIKit view managed by this representable.
  typealias UIViewType = SelectableCodeTextView

  /// Holds the complete source requested by SwiftUI.
  let source: String

  /// Holds the language used for syntax highlighting.
  let language: CodeLanguage

  /// Holds the scaled monospaced font size.
  let fontSize: CGFloat

  /// Holds the extra vertical space between source lines.
  let lineSpacing: CGFloat

  /// Holds whether long source lines wrap.
  let lineWrapping: CodeLineWrapping

  /// Holds the number of character advances represented by one tab.
  let tabWidth: Int

  /// Holds the color used by unhighlighted source.
  let textColor: Color

  /// Holds whether syntax captures should be colored.
  let syntaxHighlighting: CodeSyntaxHighlighting

  /// Holds the theme used to resolve syntax captures.
  let syntaxTheme: HighlightTheme

  /// Holds the physical insets around the left-to-right source text.
  let textInsets: UIEdgeInsets

  /// Holds the physical insets around the horizontal indicator.
  let indicatorInsets: UIEdgeInsets

  /// Holds the resolved UIKit indicator style.
  let indicatorStyle: UIScrollView.IndicatorStyle

  /// Holds whether horizontal scrolling may rubber-band.
  let scrollBounce: CodeScrollBounce

  /// Creates the coordinator that owns incremental highlighting state.
  ///
  /// - Returns: A coordinator dedicated to this rendered code block.
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  /// Returns the size required by the TextKit layout at a proposed width.
  ///
  /// - Parameters:
  ///   - proposal: The size proposed by the surrounding SwiftUI layout.
  ///   - textView: The configured selectable text view.
  ///   - context: The current representable context.
  /// - Returns: A fitting size or `nil` before a usable width is available.
  func sizeThatFits(
    _ proposal: ProposedViewSize,
    uiView textView: SelectableCodeTextView,
    context: Context
  ) -> CGSize? {
    let width = proposal.replacingUnspecifiedDimensions(
      by: CGSize(width: textView.bounds.width, height: 0)
    ).width

    guard width > 0 else {
      return nil
    }

    return CGSize(
      width: width,
      height: textView.height(fittingWidth: width)
    )
  }

  /// Creates and initially configures the selectable TextKit view.
  ///
  /// - Parameter context: The context that owns the incremental coordinator.
  /// - Returns: A selectable code text view using TextKit 2.
  func makeUIView(context: Context) -> SelectableCodeTextView {
    let textView = SelectableCodeTextView()
    configure(textView)
    context.coordinator.enqueue(rendition, in: textView)
    return textView
  }

  /// Synchronizes a reused TextKit view with the latest SwiftUI values.
  ///
  /// - Parameters:
  ///   - textView: The selectable code text view being updated.
  ///   - context: The context that owns the incremental coordinator.
  func updateUIView(
    _ textView: SelectableCodeTextView,
    context: Context
  ) {
    configure(textView)
    context.coordinator.enqueue(rendition, in: textView)
  }

  /// Stops pending highlighting work when SwiftUI removes the UIKit view.
  ///
  /// - Parameters:
  ///   - uiView: The text view leaving the hierarchy.
  ///   - coordinator: The coordinator whose work should be cancelled.
  static func dismantleUIView(
    _ uiView: SelectableCodeTextView,
    coordinator: Coordinator
  ) {
    coordinator.cancel()
  }

  /// Returns the complete source and appearance requested by this update.
  private var rendition: CodeRendition {
    CodeRendition(
      source: source,
      language: language,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      lineWrapping: lineWrapping,
      tabWidth: tabWidth,
      textColor: textColor,
      syntaxHighlighting: syntaxHighlighting,
      syntaxTheme: syntaxTheme
    )
  }

  /// Applies interaction, scrolling, and geometry options to a text view.
  ///
  /// - Parameter textView: The view that should receive the options.
  private func configure(_ textView: SelectableCodeTextView) {
    textView.backgroundColor = .clear
    textView.isEditable = false
    textView.isSelectable = true
    textView.isScrollEnabled = true
    textView.showsHorizontalScrollIndicator = lineWrapping == .disabled
    textView.showsVerticalScrollIndicator = false
    textView.bounces = scrollBounce.isEnabled
    textView.alwaysBounceHorizontal = false
    textView.alwaysBounceVertical = false
    textView.isDirectionalLockEnabled = true
    textView.semanticContentAttribute = .forceLeftToRight
    textView.contentInsetAdjustmentBehavior = .never
    textView.contentInset = .zero
    textView.automaticallyAdjustsScrollIndicatorInsets = false

    textView.textContainerInset = textInsets
    textView.horizontalScrollIndicatorInsets = indicatorInsets
    textView.indicatorStyle = indicatorStyle
    textView.lineWrapping = lineWrapping
  }

  /// Owns the ordered highlighting and TextKit rendering state for one view.
  @MainActor
  final class Coordinator {
    /// Reuses one Tree-sitter session across the block's source revisions.
    private let highlighter = StreamingHighlighter()

    /// Holds the latest rendition requested by SwiftUI.
    private var latestRendition: CodeRendition?

    /// Holds the newest rendition waiting to be highlighted.
    private var pendingRendition: CodeRendition?

    /// Retains the single task that drains pending renditions in order.
    private var processingTask: Task<Void, Never>?

    /// Holds the rendition currently represented by the TextKit storage.
    private var appliedRendition: CodeRendition?

    /// Holds the parsed revision whose styles remain in the TextKit storage.
    private var appliedSnapshot: HighlightSnapshot?

    /// Applies snapshots and incremental updates to the TextKit storage.
    private var renderer: TextKitHighlightRenderer?

    /// Caches measured logical lines for incremental horizontal sizing.
    private var lineWidthCache = CodeLineWidthCache()

    /// Avoids retaining the UIKit view beyond its SwiftUI lifetime.
    private weak var textView: SelectableCodeTextView?

    /// Returns whether this coordinator has an active highlighting processor.
    var isProcessingHighlights: Bool {
      processingTask != nil
    }

    /// Accepts a new SwiftUI rendition and starts coalesced processing.
    ///
    /// - Parameters:
    ///   - rendition: The complete source and appearance to present.
    ///   - textView: The TextKit view that should receive rendered updates.
    func enqueue(
      _ rendition: CodeRendition,
      in textView: SelectableCodeTextView
    ) {
      self.textView = textView

      guard latestRendition != rendition else {
        textView.setNeedsLayout()
        return
      }

      latestRendition = rendition

      if let appliedRendition,
        appliedRendition.hasSameAppearance(as: rendition)
      {
        applySource(rendition, to: textView)
      } else {
        applyPlain(rendition, to: textView)
      }

      guard rendition.syntaxHighlighting == .automatic else {
        pendingRendition = nil
        return
      }

      pendingRendition = rendition
      startProcessingIfNeeded()
    }

    /// Cancels pending work and releases the associated UIKit view.
    func cancel() {
      processingTask?.cancel()
      processingTask = nil
      pendingRendition = nil
      textView = nil
    }

    /// Starts the sole processor task when one is not already running.
    private func startProcessingIfNeeded() {
      guard processingTask == nil else {
        return
      }

      processingTask = Task { [weak self] in
        await self?.processPendingRenditions()
      }
    }

    /// Drains the newest pending rendition after one display-frame interval.
    ///
    /// Only this method calls ``StreamingHighlighter``, which preserves
    /// revision order even when SwiftUI supplies source updates faster than
    /// Tree-sitter can process them.
    private func processPendingRenditions() async {
      while !Task.isCancelled {
        guard pendingRendition != nil else {
          break
        }

        try? await Task.sleep(for: Metrics.coalescingInterval)

        guard
          !Task.isCancelled,
          let rendition = pendingRendition
        else {
          continue
        }

        pendingRendition = nil

        do {
          let result = try await highlighter.highlight(
            rendition.source,
            as: rendition.language
          )

          guard !Task.isCancelled else {
            continue
          }

          apply(result, for: rendition)
        } catch {
          guard
            let textView,
            latestRendition == rendition
          else {
            continue
          }

          applyPlain(rendition, to: textView)
        }
      }

      if !Task.isCancelled {
        processingTask = nil
      }
    }

    /// Applies highlighted work when its appearance is still current.
    ///
    /// A stale result still advances the parser session, but it does not
    /// replace newer source already visible in TextKit. The next current
    /// result can then update or rebuild the styles from that parser state.
    ///
    /// - Parameters:
    ///   - result: The complete snapshot or incremental update to render.
    ///   - rendition: The source and appearance represented by the result.
    private func apply(
      _ result: StreamingHighlightResult,
      for rendition: CodeRendition
    ) {
      guard
        let textView,
        let latestRendition,
        latestRendition.source == result.snapshot.text,
        latestRendition.hasSameAppearance(as: rendition),
        latestRendition.syntaxHighlighting == .automatic
      else {
        return
      }

      do {
        let renderer = preparedRenderer(for: rendition)

        switch result {
        case .snapshot(let snapshot):
          try renderComplete(
            snapshot,
            rendition: rendition,
            renderer: renderer,
            in: textView
          )

        case .update(let previousSource, _, let update):
          if textView.textStorage.string == update.snapshot.text,
            appliedSnapshot?.text == previousSource,
            appliedRendition?.hasSameAppearance(as: rendition) == true
          {
            try renderIncremental(
              update,
              rendition: rendition,
              renderer: renderer,
              in: textView
            )
          } else {
            try renderComplete(
              update.snapshot,
              rendition: rendition,
              renderer: renderer,
              in: textView
            )
          }
        }

        appliedRendition = rendition
        appliedSnapshot = result.snapshot
      } catch {
        applyPlain(rendition, to: textView)
      }
    }

    /// Returns a renderer configured for the requested theme and font.
    ///
    /// - Parameter rendition: The appearance that should be rendered.
    /// - Returns: The cached or newly created TextKit renderer.
    private func preparedRenderer(
      for rendition: CodeRendition
    ) -> TextKitHighlightRenderer {
      if let renderer {
        if renderer.theme != rendition.syntaxTheme {
          renderer.theme = rendition.syntaxTheme
        }

        if !renderer.font.isEqual(rendition.font) {
          renderer.font = rendition.font
        }

        return renderer
      }

      let renderer = TextKitHighlightRenderer(
        theme: rendition.syntaxTheme,
        font: rendition.font
      )
      self.renderer = renderer
      return renderer
    }

    /// Replaces the TextKit contents and renders a complete snapshot.
    ///
    /// - Parameters:
    ///   - snapshot: The complete highlighted source revision.
    ///   - rendition: The appearance applied beneath syntax styles.
    ///   - renderer: The configured TextKit renderer.
    ///   - textView: The destination selectable text view.
    /// - Throws: ``TextKitRenderingError`` when the snapshot cannot be rendered.
    private func renderComplete(
      _ snapshot: HighlightSnapshot,
      rendition: CodeRendition,
      renderer: TextKitHighlightRenderer,
      in textView: SelectableCodeTextView
    ) throws(TextKitRenderingError) {
      let previousSource = textView.textStorage.string
      let previousSelection = textView.selectedRange
      let previousOffset = textView.contentOffset
      let preservesInteraction =
        previousSource == snapshot.text
        || snapshot.text.hasPrefix(previousSource)

      textView.textStorage.setAttributedString(
        rendition.attributedSource(snapshot.text)
      )
      try renderer.render(snapshot, in: textView.textStorage)
      rebuildGeometry(of: textView, using: rendition)

      if preservesInteraction {
        textView.selectedRange = previousSelection.clamped(
          toLength: snapshot.text.utf16.count
        )
        textView.restoreContentOffset(previousOffset)
      } else {
        textView.selectedRange = NSRange(location: 0, length: 0)
        textView.scrollToLeadingEdge()
      }
    }

    /// Applies incremental styles to source already updated in TextKit.
    ///
    /// - Parameters:
    ///   - update: The highlight update produced after the source edit.
    ///   - rendition: The appearance applied beneath syntax styles.
    ///   - renderer: The configured TextKit renderer.
    ///   - textView: The destination selectable text view.
    /// - Throws: ``TextKitRenderingError`` when the update cannot be rendered.
    private func renderIncremental(
      _ update: HighlightUpdate,
      rendition: CodeRendition,
      renderer: TextKitHighlightRenderer,
      in textView: SelectableCodeTextView
    ) throws(TextKitRenderingError) {
      let previousSelection = textView.selectedRange
      let previousOffset = textView.contentOffset

      try renderer.render(update, in: textView.textStorage)
      refreshGeometry(
        of: textView,
        using: rendition,
        renderingRanges: update.renderingRanges
      )
      textView.selectedRange = previousSelection.clamped(
        toLength: update.snapshot.text.utf16.count
      )
      textView.restoreContentOffset(previousOffset)
    }

    /// Applies the newest source before its coalesced highlighting completes.
    ///
    /// Existing attributes move with unaffected text, while inserted source
    /// receives the base style until the matching parser update arrives.
    ///
    /// - Parameters:
    ///   - rendition: The complete source and appearance to present.
    ///   - textView: The destination selectable text view.
    private func applySource(
      _ rendition: CodeRendition,
      to textView: SelectableCodeTextView
    ) {
      guard
        let edit = SourceEdit.difference(
          from: textView.textStorage.string,
          to: rendition.source
        )
      else {
        appliedRendition = rendition
        return
      }

      let previousSelection = textView.selectedRange
      let previousOffset = textView.contentOffset
      let replacementRange = edit.replacementRange

      textView.textStorage.beginEditing()
      textView.textStorage.replaceCharacters(
        in: NSRange(
          location: edit.range.location,
          length: edit.range.length
        ),
        with: edit.replacement
      )

      if replacementRange.length > 0 {
        textView.textStorage.setAttributes(
          rendition.baseAttributes,
          range: NSRange(
            location: replacementRange.location,
            length: replacementRange.length
          )
        )
      }
      textView.textStorage.endEditing()

      appliedRendition = rendition
      refreshGeometry(
        of: textView,
        using: rendition,
        sourceEdit: edit
      )
      textView.selectedRange = previousSelection.applying(
        edit,
        resultingLength: rendition.source.utf16.count
      )
      textView.restoreContentOffset(previousOffset)
    }

    /// Presents readable plain source when highlighting is disabled or fails.
    ///
    /// - Parameters:
    ///   - rendition: The source and base appearance to present.
    ///   - textView: The destination selectable text view.
    private func applyPlain(
      _ rendition: CodeRendition,
      to textView: SelectableCodeTextView
    ) {
      let previousSource = textView.textStorage.string
      let previousSelection = textView.selectedRange
      let previousOffset = textView.contentOffset
      let preservesInteraction =
        previousSource == rendition.source
        || rendition.source.hasPrefix(previousSource)

      textView.textStorage.setAttributedString(
        rendition.attributedSource(rendition.source)
      )
      renderer = nil
      appliedSnapshot = nil
      appliedRendition = rendition

      rebuildGeometry(of: textView, using: rendition)

      if preservesInteraction {
        textView.selectedRange = previousSelection.clamped(
          toLength: rendition.source.utf16.count
        )
        textView.restoreContentOffset(previousOffset)
      } else {
        textView.selectedRange = NSRange(location: 0, length: 0)
        textView.scrollToLeadingEdge()
      }
    }

    /// Rebuilds horizontal geometry after a complete storage replacement.
    ///
    /// - Parameters:
    ///   - textView: The view whose layout should be refreshed.
    ///   - rendition: The appearance used to measure the rendered source.
    private func rebuildGeometry(
      of textView: SelectableCodeTextView,
      using rendition: CodeRendition
    ) {
      guard rendition.lineWrapping == .disabled else {
        lineWidthCache.removeAll()
        updateGeometry(of: textView, widestLineWidth: 1)
        return
      }

      lineWidthCache.rebuild(from: textView.textStorage)
      updateGeometry(
        of: textView,
        widestLineWidth: lineWidthCache.widestLineWidth
      )
    }

    /// Refreshes horizontal geometry after one source replacement.
    ///
    /// - Parameters:
    ///   - textView: The view whose layout should be refreshed.
    ///   - rendition: The appearance used to measure the rendered source.
    ///   - sourceEdit: The replacement already applied to TextKit storage.
    private func refreshGeometry(
      of textView: SelectableCodeTextView,
      using rendition: CodeRendition,
      sourceEdit: SourceEdit
    ) {
      guard rendition.lineWrapping == .disabled else {
        lineWidthCache.removeAll()
        updateGeometry(of: textView, widestLineWidth: 1)
        return
      }

      lineWidthCache.update(
        after: sourceEdit,
        in: textView.textStorage
      )
      updateGeometry(
        of: textView,
        widestLineWidth: lineWidthCache.widestLineWidth
      )
    }

    /// Refreshes horizontal geometry after incremental syntax styling.
    ///
    /// - Parameters:
    ///   - textView: The view whose layout should be refreshed.
    ///   - rendition: The appearance used to measure the rendered source.
    ///   - renderingRanges: The ranges whose font traits may have changed.
    private func refreshGeometry(
      of textView: SelectableCodeTextView,
      using rendition: CodeRendition,
      renderingRanges: [UTF16Range]
    ) {
      guard rendition.lineWrapping == .disabled else {
        lineWidthCache.removeAll()
        updateGeometry(of: textView, widestLineWidth: 1)
        return
      }

      lineWidthCache.remeasure(
        linesIntersecting: renderingRanges,
        in: textView.textStorage
      )
      updateGeometry(
        of: textView,
        widestLineWidth: lineWidthCache.widestLineWidth
      )
    }

    /// Invalidates layout after changing the cached horizontal extent.
    ///
    /// - Parameters:
    ///   - textView: The view whose layout should be refreshed.
    ///   - widestLineWidth: The measured width of the widest logical line.
    private func updateGeometry(
      of textView: SelectableCodeTextView,
      widestLineWidth: CGFloat
    ) {
      textView.widestLineWidth = widestLineWidth
      textView.setNeedsLayout()
      textView.invalidateIntrinsicContentSize()
    }

    /// Stores the brief interval used to combine rapid token updates.
    private enum Metrics {
      /// Limits highlighting work to approximately one update per display frame.
      static let coalescingInterval = Duration.milliseconds(16)
    }
  }
}

/// Contains every value that changes rendered source appearance.
struct CodeRendition: Equatable {
  /// Holds the complete source text.
  let source: String

  /// Holds the language used for syntax highlighting.
  let language: CodeLanguage

  /// Holds the scaled monospaced font size.
  let fontSize: CGFloat

  /// Holds the extra vertical space between source lines.
  let lineSpacing: CGFloat

  /// Holds whether long source lines wrap.
  let lineWrapping: CodeLineWrapping

  /// Holds the number of character advances represented by one tab.
  let tabWidth: Int

  /// Holds the color used by unhighlighted source.
  let textColor: Color

  /// Holds whether syntax captures should be colored.
  let syntaxHighlighting: CodeSyntaxHighlighting

  /// Holds the theme used to resolve syntax captures.
  let syntaxTheme: HighlightTheme

  /// Returns the monospaced base font used by TextKit and the renderer.
  var font: UIFont {
    UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
  }

  /// Returns the base attributes applied before syntax-specific styles.
  var baseAttributes: [NSAttributedString.Key: Any] {
    let font = font
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = lineSpacing
    paragraphStyle.lineBreakMode = lineWrapping.lineBreakMode
    paragraphStyle.baseWritingDirection = .leftToRight
    paragraphStyle.tabStops = []

    let characterWidth = ("0" as NSString).size(
      withAttributes: [.font: font]
    ).width
    paragraphStyle.defaultTabInterval = characterWidth * CGFloat(tabWidth)

    return [
      .font: font,
      .foregroundColor: UIColor(textColor),
      .paragraphStyle: paragraphStyle,
    ]
  }

  /// Returns whether two renditions differ only in their source strings.
  ///
  /// - Parameter other: The rendition whose appearance should be compared.
  /// - Returns: `true` when incremental TextKit rendering can reuse its styles.
  func hasSameAppearance(as other: Self) -> Bool {
    language == other.language
      && fontSize == other.fontSize
      && lineSpacing == other.lineSpacing
      && lineWrapping == other.lineWrapping
      && tabWidth == other.tabWidth
      && textColor == other.textColor
      && syntaxHighlighting == other.syntaxHighlighting
      && syntaxTheme == other.syntaxTheme
  }

  /// Creates base attributed source before syntax styles are applied.
  ///
  /// - Parameter source: The source to place in TextKit storage.
  /// - Returns: Source containing the configured base attributes.
  func attributedSource(_ source: String) -> NSAttributedString {
    NSAttributedString(string: source, attributes: baseAttributes)
  }
}
