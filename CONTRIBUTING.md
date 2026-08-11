# Contributing

Contributions and focused bug reports are welcome. Open an issue before a large
change so its public API and platform scope can be discussed early.

## Development

Rork Code Block requires Swift 6 and an Xcode installation with an available
iOS simulator. Choose a simulator identifier when running tests locally.

```bash
make format
make check SIMULATOR_ID=<simulator-udid>
```

The check command lints Swift sources, builds the package, generates its
documentation, runs the simulator test suite, and builds the example app.

The example project is generated with the Tuist version pinned in `mise.toml`.
`Project.swift` is its source of truth, and generated Xcode files remain
ignored.

```bash
make generate-example
```

New public and internal declarations need complete documentation. Comments
should explain intent or a non-obvious constraint in short natural prose.

## Pull requests

Keep each pull request focused and include tests for behavior changes. Use a
Conventional Commits title such as `feat: add a compact code block style` or
`fix: preserve selection during streamed updates`.
