# Styling Code Blocks

Use environment modifiers for common appearance changes and a code block style
when the surrounding layout should change.

## Adjust the default card

The default style reads its fill, border, label treatment, radius, and source
spacing from the SwiftUI environment.

```swift
CodeBlock(source, language: .swift)
    .codeFontSize(14)
    .codeLineSpacing(3)
    .codeTabWidth(2)
    .codeBlockCornerRadius(16)
    .codeBlockContentInsets(
        EdgeInsets(top: 8, leading: 14, bottom: 18, trailing: 14)
    )
    .codeBlockBackgroundStyle(.thinMaterial)
    .codeBlockBorderStyle(.white.opacity(0.12))
```

Apply a modifier to an enclosing view when several blocks should share the
same treatment.

## Choose text behavior

Unwrapped lines retain source alignment and scroll horizontally. Wrapping is
available for narrow layouts.

```swift
CodeBlock(source, language: .typescript)
    .codeLineWrapping(.enabled)
    .codeSyntaxHighlighting(.automatic)
```

Use `.codeSyntaxTheme(_:)` to select a Rork Highlighter theme.
Passing `nil` follows the effective light or dark card appearance.

## Replace the chrome

Implement ``CodeBlockStyle`` when the source, language label, and copy control
need another arrangement. The configuration supplies a ready-to-place source
view and copy button.

```swift
struct CompactCodeBlockStyle: CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(configuration.languageName)
                Spacer()
                configuration.copyButton
            }
            .font(.caption)

            configuration.content
        }
        .padding(10)
        .background(.quaternary.opacity(0.35))
        .clipShape(.rect(cornerRadius: 12))
    }
}
```

A style that always draws a light or dark background should return that value
from ``CodeBlockStyle/codeAppearance``. The component uses it to choose
legible syntax colors and a matching scroll indicator.
