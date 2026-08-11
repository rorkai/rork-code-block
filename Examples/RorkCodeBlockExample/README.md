# Rork Code Block Example

The example app demonstrates static and rapidly streaming source with the
adaptive, terminal, and custom code block styles. It supports iOS, Mac Catalyst,
and visionOS from one Xcode target.

Generate the workspace, open `RorkCodeBlockExample.xcworkspace`, choose a
destination, and run the `RorkCodeBlockExample` scheme. The project uses the
repository root as a local Swift package dependency, so edits to the library
appear in the app directly.

```bash
make generate-example
```

Build the iOS Simulator destination from the repository root when a visual run
is not needed:

```bash
make build-example
```

Use `make build-example-platforms` to compile the app for every supported
destination.

`Project.swift` is the source of truth. The generated Xcode project and
workspace remain ignored so project configuration never drifts from the Tuist
manifest.
