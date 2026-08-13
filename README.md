# Rork Code Block

Rork Code Block is a native SwiftUI component for selectable, copyable, and
syntax-highlighted source code. It is designed for both complete snippets and
rapidly streaming responses.

[![CI](https://github.com/rorkai/rork-code-block/actions/workflows/ci.yml/badge.svg)](https://github.com/rorkai/rork-code-block/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)

```swift
import RorkCodeBlock
import SwiftUI

struct ExampleView: View {
    private let source = #"""
    import SwiftUI

    struct WelcomeView: View {
        var body: some View {
            Text("Hello, Rork!")
        }
    }
    """#

    var body: some View {
        CodeBlock(source, language: .swift)
            .padding()
    }
}
```

The block renders accurate Tree-sitter syntax styles through Rork Highlighter.
It grows vertically with its content and scrolls long lines horizontally, which
makes it comfortable inside an existing `ScrollView`.

## Example app

The runnable [example app](Examples/RorkCodeBlockExample) demonstrates static
and rapidly streaming source, language switching, and every bundled card style.
It uses this checkout as a local package dependency and runs on iOS, Mac
Catalyst, and visionOS.

## What it is designed for

- Streamed AI responses whose source changes several times per second.
- Markdown renderers, documentation, previews, and chat transcripts.
- Static snippets that need selection, copying, and native accessibility.
- Product-specific code cards built with a reusable SwiftUI style.

Each visible block owns an incremental highlighting session. Rapid revisions
are coalesced, parsed in order, and applied to TextKit 2 without rebuilding the
complete attributed string when an incremental update is available.

## Requirements

- Swift 6.0 or newer.
- iOS 17 or newer.
- Mac Catalyst 17 or newer.
- visionOS 1 or newer.

Rork Code Block currently uses the UIKit-backed SwiftUI integration on every
supported platform. Native AppKit support is not included in this release.

## Installation

Add the package dependency:

```swift
.package(
    url: "https://github.com/rorkai/rork-code-block.git",
    .upToNextMinor(from: "0.1.0")
)
```

Add the library product to your target:

```swift
.product(
    name: "RorkCodeBlock",
    package: "rork-code-block"
)
```

Your application imports `RorkCodeBlock`. The package brings in Rork
Highlighter and its bundled Tree-sitter language catalog.

## Streaming source

Streaming does not require a separate view or controller. Update the same
source value you would use for a static block:

```swift
import RorkCodeBlock
import SwiftUI

struct StreamingResponse: View {
    let chunks: AsyncStream<String>

    @State private var source = ""

    var body: some View {
        CodeBlock(source, language: .typescript)
            .task {
                for await chunk in chunks {
                    source += chunk
                }
            }
    }
}
```

Highlighting work is combined over a brief display-frame interval, and later
revisions reuse the block's existing Tree-sitter syntax tree. In automatic
mode, each visible source revision and its exact syntax styles are committed to
TextKit together. This prevents an unhighlighted source frame from appearing
while the matching parser result is still in flight. The visible source can
therefore trail the producer by one coalescing interval during a rapid stream.

If stable plain text is preferable while chunks arrive, pass the producer's
streaming state and highlight once it finishes:

```swift
CodeBlock(source, language: .typescript)
    .codeSyntaxHighlighting(.deferred(whileStreaming: isStreaming))
```

This explicit state avoids guessing whether a slow stream has ended.

## Styling

The adaptive default card follows the surrounding color scheme. Common visual
changes use regular view modifiers:

```swift
CodeBlock(source, language: .swift)
    .codeFontSize(14)
    .codeLineSpacing(3)
    .codeBlockCornerRadius(16)
    .codeBlockBackgroundStyle(.thinMaterial)
    .codeBlockBorderStyle(.white.opacity(0.12))
```

Use the bundled terminal style when a fixed dark presentation fits the screen:

```swift
CodeBlock(source, language: .swift)
    .codeBlockStyle(.terminal)
```

A custom style owns the surrounding chrome while the component continues to
own selection, scrolling, copying, and highlighting:

```swift
struct PlainCodeBlockStyle: CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            configuration.copyButton
                .padding(8)

            configuration.content
        }
        .background(.quaternary.opacity(0.35))
        .clipShape(.rect(cornerRadius: 12))
    }
}

CodeBlock(source, language: .swift)
    .codeBlockStyle(PlainCodeBlockStyle())
```

See [Styling Code Blocks](Sources/RorkCodeBlock/RorkCodeBlock.docc/StylingCodeBlocks.md)
for the complete set of environment modifiers and style configuration values.

## Languages and themes

Typed language identifiers keep common call sites concise:

```swift
CodeBlock(swiftSource, language: .swift)
CodeBlock(webSource, language: .typescript)
CodeBlock(markdownSource, language: .markdown)
```

A string name or alias is also accepted. Unknown languages remain readable and
fall back to the configured plain text color.

```swift
CodeBlock(source, language: "Objective-C")
```

The standard catalog comes from Rork Highlighter and covers the common mobile,
React Native, Expo, and modern web development stack. See the
[bundled language guide](https://github.com/rorkai/rork-highlighter/blob/main/Sources/RorkHighlighter/RorkHighlighter.docc/BundledLanguages.md)
for the current list.

Import Rork Highlighter when selecting or constructing a syntax theme:

```swift
import RorkCodeBlock
import RorkHighlighter

CodeBlock(source, language: .swift)
    .codeSyntaxTheme(.rorkDark)
```

## Performance

Rork Code Block keeps its rendering path native. It uses one actor-isolated
Rork Highlighter session per visible block, coalesces bursts of source updates,
and commits source edits with focused UTF-16 rendering ranges through TextKit 2.
The standard immutable highlighter is initialized once per process and shared
by all blocks.

Run the component's incremental benchmark on an available iOS simulator:

```bash
make benchmark SIMULATOR_ID=<simulator-udid>
```

The benchmark deliberately excludes the fixed coalescing interval and measures
successive source revisions through the streaming wrapper. Parser, query, and
TextKit microbenchmarks live in the
[Rork Highlighter benchmark suite](https://github.com/rorkai/rork-highlighter/tree/main/Benchmarks).

See [Benchmarks](Benchmarks/README.md) for the measurement contract.

## Rork Highlighter

This package owns a ready-to-use SwiftUI code block. Use
[Rork Highlighter](https://github.com/rorkai/rork-highlighter) directly when you
need semantic spans, an editor integration, AppKit, attributed output, or a
custom Core Text or Metal renderer.

## License

Rork Code Block is available under Apache-2.0. See [LICENSE](LICENSE).
