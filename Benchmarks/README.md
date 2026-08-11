# Benchmarks

The component benchmark suite measures two alternating incremental edits near
the end of a representative 500-line Swift source file. The highlighting
measurement uses the same warm `StreamingHighlighter` wrapper as a visible code
block. The horizontal sizing measurement uses the same logical-line cache and
TextKit storage as the rendering path. Both record release-build wall clock
time with Xcode's performance test support.

The suite lives in an isolated Swift package so the parent `RorkCodeBlock`
module can be compiled with `ENABLE_TESTABILITY=NO`. Benchmark-only access uses
Swift's SPI boundary and does not make rendering internals part of the public
library API.

The fixed display-frame coalescing interval is intentionally outside the
measurement. That interval limits work during bursty streams and is not parser
or rendering time.

Choose an available iOS simulator and run the benchmark from the repository
root:

```bash
make benchmark SIMULATOR_ID=<simulator-udid>
```

List available identifiers when needed:

```bash
xcrun simctl list devices available
```

Results depend on the machine, build configuration, simulator runtime, and
toolchain. Compare changes on the same machine and destination. Rork
Highlighter owns the lower-level parser, query, and TextKit benchmark suite so
this repository does not duplicate those measurements.

## Reference result

The production-configured benchmark produced the following warm result on an
Apple M5 Max with Xcode 26.6 and Swift 6.3.3. It used an iPhone 17 Pro simulator
and the release configuration.

| Workload | Mean | Samples |
| --- | ---: | ---: |
| Incremental 500-line Swift tail edit | 0.451 ms | 5 |
| Incremental 500-line width update | 0.002 ms per edit | 5 batches of 1,000 |

This value is a local reference rather than a cross-machine performance claim.
