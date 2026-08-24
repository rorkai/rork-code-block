// swift-tools-version: 6.0

import PackageDescription

/// Defines the public SwiftUI component and its highlighting dependency.
private let rorkCodeBlockTarget: Target = .target(
  name: "RorkCodeBlock",
  dependencies: [
    .product(
      name: "RorkHighlighter",
      package: "rork-highlighter"
    )
  ]
)

/// Defines the tests for public behavior and streaming internals.
private let rorkCodeBlockTestsTarget: Target = .testTarget(
  name: "RorkCodeBlockTests",
  dependencies: [
    "RorkCodeBlock",
    .product(
      name: "RorkHighlighter",
      package: "rork-highlighter"
    ),
  ]
)

/// Defines the native SwiftUI code block package.
let package = Package(
  name: "rork-code-block",
  platforms: [
    .macCatalyst(.v17),
    .iOS(.v17),
    .visionOS(.v1),
  ],
  products: [
    .library(
      name: "RorkCodeBlock",
      targets: ["RorkCodeBlock"]
    )
  ],
  dependencies: [
    .package(
      url: "https://github.com/rorkai/rork-highlighter.git",
      .upToNextMinor(from: "0.4.0")
    )
  ],
  targets: [
    rorkCodeBlockTarget,
    rorkCodeBlockTestsTarget,
  ],
  swiftLanguageModes: [.v6]
)
