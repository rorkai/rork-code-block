// swift-tools-version: 6.0

import PackageDescription

/// Defines production-configured benchmarks for the parent package.
private let productionBenchmarksTarget: Target = .testTarget(
  name: "RorkCodeBlockProductionBenchmarks",
  dependencies: [
    .product(
      name: "RorkCodeBlock",
      package: "rork-code-block"
    )
  ]
)

/// Defines the isolated benchmark package.
let package = Package(
  name: "rork-code-block-production-benchmarks",
  platforms: [.iOS(.v17)],
  dependencies: [.package(path: "../..")],
  targets: [productionBenchmarksTarget],
  swiftLanguageModes: [.v6]
)
