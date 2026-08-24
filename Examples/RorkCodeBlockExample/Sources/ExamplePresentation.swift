/// Identifies one code block presentation available in the example app.
enum ExamplePresentation: String, CaseIterable, Identifiable {
  /// Uses the adaptive bordered card supplied by the package.
  case adaptive = "Adaptive"

  /// Uses the fixed dark terminal card supplied by the package.
  case terminal = "Terminal"

  /// Uses the compact custom style declared by the example app.
  case minimal = "Minimal"

  /// Uses the enum value itself as stable picker identity.
  var id: Self { self }
}
