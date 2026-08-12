# Streaming Updates

Render changing source through the same value-driven API used for a complete
snippet.

## Supply the latest source

Keep the complete source in view state and append each incoming chunk. Rork
Code Block observes each value revision and manages incremental highlighting
internally.

```swift
import RorkCodeBlock
import SwiftUI

struct StreamingResponse: View {
    let chunks: AsyncStream<String>

    @State private var source = ""

    var body: some View {
        CodeBlock(source, language: .swift)
            .task {
                for await chunk in chunks {
                    source += chunk
                }
            }
    }
}
```

There is no separate streaming view or controller. This keeps the source of
truth in the parent view and makes the component work with any producer,
including an async sequence, an observation model, or a reducer.

## Choose when highlighting runs

Incremental highlighting is enabled by default. Apps that prefer stable plain
text during generation can supply their existing streaming state:

```swift
CodeBlock(source, language: .swift)
    .codeSyntaxHighlighting(.deferred(whileStreaming: isStreaming))
```

The source remains selectable and updates immediately while `isStreaming` is
`true`. Changing it to `false` highlights the complete current source. The
explicit state works for streams with arbitrary pauses because the component
does not need to infer when generation has ended.

## Understand the update path

The TextKit view receives plain source synchronously so rendering never waits
for parser initialization. The block combines rapid revisions over a short
display-frame interval, then submits the newest source to its actor-isolated
highlighting session.

The first highlighted revision opens a Tree-sitter session. Later revisions
calculate one UTF-16 replacement, incrementally edit the syntax tree, and apply
focused rendering ranges through TextKit. During append-only bursts, captures
established when a line completes remain stable while previously unresolved
syntax can accept newly recognized captures. The active line always follows
the current syntax tree. This prevents temporary error recovery around an
unfinished token or expression from making earlier declarations flicker or
delaying newly resolved colors. One complete render restores the exact latest
snapshot after updates pause.

A replacement elsewhere in the source continues to use the complete
invalidation ranges reported by Rork Highlighter. A language or theme change
rebuilds the affected presentation without leaking state between blocks.

Unknown languages and highlighting failures leave the complete plain source
visible. They do not turn a rendering concern into a failed SwiftUI update.

## Preserve readable layout

The block grows to the complete TextKit height so it fits naturally inside a
page-level scroll view. Long lines scroll horizontally by default. Enable
`.codeLineWrapping(_:)` when preserving each logical source line
is less important than fitting the available width.
