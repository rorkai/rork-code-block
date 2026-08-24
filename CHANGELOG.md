# Changelog

Notable changes are recorded in this file.

## Unreleased

### Added

- A native SwiftUI code block for iOS, Mac Catalyst, and visionOS.
- Incremental Tree-sitter highlighting for streamed source revisions.
- Selectable TextKit 2 output with copying, horizontal scrolling, and wrapping.
- Adaptive default and terminal styles with environment-based customization.

### Fixed

- Streaming highlighting now colors only settled syntax, keeps the uncertain
  tail neutral, and preserves last settled colors while Tree-sitter recovery
  temporarily reinterprets revealed source. Streamed colors no longer flicker
  or differ from the finished snippet.
- Syntax held inside long-running parser recovery, such as a call with a
  streaming trailing closure, colors once its classification has outlived a
  short stretch of appended source instead of staying neutral until its
  closing braces arrive. Survival is measured in source units, so streams
  with character-sized or coarse chunks behave the same as the example's
  cadence.
- Ending a stream reconciles with a fresh parse, so the final colors always
  equal one-shot highlighting of the completed source.
- Replaying a stream over an already rendered snippet repaints the rebuilt
  presentation completely, so the earliest streamed tokens color while the
  stream runs instead of waiting for reconciliation.
