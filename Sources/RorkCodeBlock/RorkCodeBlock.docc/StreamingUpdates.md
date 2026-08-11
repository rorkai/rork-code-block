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

There is no separate streaming mode. This keeps the source of truth in the
parent view and makes the component work with any producer, including an async
sequence, an observation model, or a reducer.

## Understand the update path

The TextKit view receives plain source synchronously so rendering never waits
for parser initialization. The block combines rapid revisions over a short
display-frame interval, then submits the newest source to its actor-isolated
highlighting session.

The first highlighted revision opens a Tree-sitter session. Later revisions
calculate one UTF-16 replacement, incrementally edit the syntax tree, and apply
focused rendering ranges through TextKit. During append-only bursts, the active
line and new suffix receive current styles while completed lines retain their
last resolved styles. This prevents temporary error recovery around an
unfinished token or expression from making earlier declarations flicker. One
complete render restores the exact latest snapshot after updates pause.

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
