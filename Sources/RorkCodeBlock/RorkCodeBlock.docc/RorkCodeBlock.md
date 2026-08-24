# ``RorkCodeBlock``

Present selectable and copyable source code with native streaming syntax
highlighting.

## Overview

Rork Code Block combines a SwiftUI card, TextKit 2 layout, and Rork
Highlighter's incremental Tree-sitter sessions. A block displays its source
immediately and updates syntax styles as highlighting work completes.

```swift
import RorkCodeBlock
import SwiftUI

struct SourcePreview: View {
    let source: String

    var body: some View {
        CodeBlock(source, language: .swift)
    }
}
```

Ordinary SwiftUI value changes drive both streamed and complete source. The
component preserves the visible source, selection, and horizontal position
while compatible revisions arrive.

## Topics

### Creating a code block

- ``CodeBlock``
- ``CodeLanguage``

### Streaming updates

- <doc:StreamingUpdates>

### Styling

- <doc:StylingCodeBlocks>
- ``CodeBlockStyle``
- ``CodeBlockStyleConfiguration``
- ``DefaultCodeBlockStyle``
- ``TerminalCodeBlockStyle``

### Text behavior

- ``CodeSyntaxHighlighting``
- ``CodeLineWrapping``
- ``CodeScrollIndicatorStyle``
- ``CodeScrollBounce``
