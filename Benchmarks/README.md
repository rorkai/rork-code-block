# Benchmarks

The component benchmark measures alternating incremental edits through the
same `StreamingHighlighter` wrapper used by a visible code block. It creates a
warm Swift session before measurement, changes a fixed-width marker near the
end of a representative 500-line source file, and records release-build wall
clock time with Xcode's performance test support.

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

The initial release benchmark produced the following warm result on an Apple
M5 Max with Xcode 26.6 and Swift 6.3.3. It used an iPhone 17 Pro simulator and
the release configuration.

| Workload | Mean | Samples |
| --- | ---: | ---: |
| Incremental 500-line Swift tail edit | 0.469 ms | 5 |

This value is a local reference rather than a cross-machine performance claim.
