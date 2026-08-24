import RorkHighlighter
import SwiftUI

extension EnvironmentValues {
  /// Stores the type-erased style inherited by a code block.
  @Entry var codeBlockStyle: AnyCodeBlockStyle?

  /// Stores the unscaled point size used by the monospaced code font.
  @Entry var codeFontSize: CGFloat = 15

  /// Stores the extra vertical space between rendered source lines.
  @Entry var codeLineSpacing: CGFloat = 2

  /// Stores the line-wrapping behavior inherited by a code block.
  @Entry var codeLineWrapping = CodeLineWrapping.disabled

  /// Stores the number of character advances represented by one tab.
  @Entry var codeTabWidth = 4

  /// Stores the color used when syntax highlighting is disabled or unavailable.
  @Entry var codeTextColor = CodeBlockPalette.text

  /// Stores when syntax captures should be colored.
  @Entry var codeSyntaxHighlighting = CodeSyntaxHighlighting.automatic

  /// Stores an explicit syntax theme or `nil` to follow the card appearance.
  @Entry var codeSyntaxTheme: HighlightTheme?

  /// Stores the corner radius used by the default style.
  @Entry var codeBlockCornerRadius: CGFloat = 24

  /// Stores the space between the card edges and its source text.
  @Entry var codeBlockContentInsets = EdgeInsets(
    top: 8,
    leading: 16,
    bottom: 20,
    trailing: 16
  )

  /// Stores the insets applied to the horizontal indicator track.
  @Entry var codeBlockScrollIndicatorInsets = EdgeInsets(
    top: 0,
    leading: 12,
    bottom: 4,
    trailing: 12
  )

  /// Stores the brightness of the horizontal scroll indicator.
  @Entry var codeBlockScrollIndicatorStyle = CodeScrollIndicatorStyle.automatic

  /// Stores whether horizontal scrolling may rubber-band at its boundaries.
  @Entry var codeBlockScrollBounce = CodeScrollBounce.automatic

  /// Stores the fill drawn by the default style.
  @Entry var codeBlockBackgroundStyle = AnyShapeStyle(CodeBlockPalette.background)

  /// Stores the border drawn by the default style.
  @Entry var codeBlockBorderStyle = AnyShapeStyle(CodeBlockPalette.border)

  /// Stores the foreground style used by labels and controls.
  @Entry var codeBlockLabelStyle = AnyShapeStyle(CodeBlockPalette.label)
}

extension View {
  /// Sets the visual arrangement used by code blocks in this view hierarchy.
  ///
  /// - Parameter style: The style that arranges the source and card chrome.
  /// - Returns: A view that supplies the style to its descendant code blocks.
  public func codeBlockStyle(_ style: some CodeBlockStyle) -> some View {
    environment(\.codeBlockStyle, AnyCodeBlockStyle(style))
  }

  /// Sets the code font size before Dynamic Type scaling.
  ///
  /// - Parameter size: The unscaled point size of the monospaced font.
  /// - Returns: A view that supplies the size to its descendant code blocks.
  public func codeFontSize(_ size: CGFloat) -> some View {
    environment(\.codeFontSize, size)
  }

  /// Sets the extra vertical space between source lines.
  ///
  /// - Parameter spacing: The additional spacing measured in points.
  /// - Returns: A view that supplies the spacing to its descendant code blocks.
  public func codeLineSpacing(_ spacing: CGFloat) -> some View {
    environment(\.codeLineSpacing, spacing)
  }

  /// Sets whether long source lines wrap or scroll horizontally.
  ///
  /// - Parameter wrapping: The requested line-wrapping behavior.
  /// - Returns: A view that supplies the behavior to descendant code blocks.
  public func codeLineWrapping(_ wrapping: CodeLineWrapping) -> some View {
    environment(\.codeLineWrapping, wrapping)
  }

  /// Sets the number of character advances represented by one tab.
  ///
  /// - Parameter characters: The positive number of monospaced characters.
  /// - Returns: A view that supplies the tab width to descendant code blocks.
  public func codeTabWidth(_ characters: Int) -> some View {
    environment(\.codeTabWidth, max(1, characters))
  }

  /// Sets the color used by unhighlighted source text.
  ///
  /// - Parameter color: The requested source color.
  /// - Returns: A view that supplies the color to descendant code blocks.
  public func codeTextColor(_ color: Color) -> some View {
    environment(\.codeTextColor, color)
  }

  /// Sets when code blocks color syntax captures.
  ///
  /// - Parameter highlighting: The requested highlighting behavior.
  /// - Returns: A view that supplies the behavior to descendant code blocks.
  public func codeSyntaxHighlighting(_ highlighting: CodeSyntaxHighlighting) -> some View {
    environment(\.codeSyntaxHighlighting, highlighting)
  }

  /// Sets the syntax theme used by code blocks.
  ///
  /// Passing `nil` selects Rork Highlighter's light or dark theme from each
  /// code block's effective appearance.
  ///
  /// - Parameter theme: The explicit theme or `nil` for automatic selection.
  /// - Returns: A view that supplies the theme to descendant code blocks.
  public func codeSyntaxTheme(_ theme: HighlightTheme?) -> some View {
    environment(\.codeSyntaxTheme, theme)
  }

  /// Sets the corner radius used by the default code block style.
  ///
  /// - Parameter radius: The nonnegative radius measured in points.
  /// - Returns: A view that supplies the radius to descendant code blocks.
  public func codeBlockCornerRadius(_ radius: CGFloat) -> some View {
    environment(\.codeBlockCornerRadius, max(0, radius))
  }

  /// Sets the space between a code block's edges and its source text.
  ///
  /// - Parameter insets: The requested directional edge insets.
  /// - Returns: A view that supplies the insets to descendant code blocks.
  public func codeBlockContentInsets(_ insets: EdgeInsets) -> some View {
    environment(\.codeBlockContentInsets, insets)
  }

  /// Sets the insets of the horizontal scroll indicator track.
  ///
  /// - Parameter insets: The requested directional edge insets.
  /// - Returns: A view that supplies the insets to descendant code blocks.
  public func codeBlockScrollIndicatorInsets(_ insets: EdgeInsets) -> some View {
    environment(\.codeBlockScrollIndicatorInsets, insets)
  }

  /// Sets the brightness of the horizontal scroll indicator.
  ///
  /// - Parameter style: The requested indicator style.
  /// - Returns: A view that supplies the style to descendant code blocks.
  public func codeBlockScrollIndicatorStyle(_ style: CodeScrollIndicatorStyle) -> some View {
    environment(\.codeBlockScrollIndicatorStyle, style)
  }

  /// Sets whether horizontal scrolling rubber-bands at its boundaries.
  ///
  /// - Parameter bounce: The requested bounce behavior.
  /// - Returns: A view that supplies the behavior to descendant code blocks.
  public func codeBlockScrollBounce(_ bounce: CodeScrollBounce) -> some View {
    environment(\.codeBlockScrollBounce, bounce)
  }

  /// Sets the fill drawn by the default code block style.
  ///
  /// - Parameter style: The shape style used to fill the card.
  /// - Returns: A view that supplies the fill to descendant code blocks.
  public func codeBlockBackgroundStyle(_ style: some ShapeStyle) -> some View {
    environment(\.codeBlockBackgroundStyle, AnyShapeStyle(style))
  }

  /// Sets the border drawn by the default code block style.
  ///
  /// - Parameter style: The shape style used to stroke the card.
  /// - Returns: A view that supplies the border to descendant code blocks.
  public func codeBlockBorderStyle(_ style: some ShapeStyle) -> some View {
    environment(\.codeBlockBorderStyle, AnyShapeStyle(style))
  }

  /// Sets the foreground style used by code block labels and controls.
  ///
  /// - Parameter style: The shape style applied to the card chrome.
  /// - Returns: A view that supplies the style to descendant code blocks.
  public func codeBlockLabelStyle(_ style: some ShapeStyle) -> some View {
    environment(\.codeBlockLabelStyle, AnyShapeStyle(style))
  }
}
