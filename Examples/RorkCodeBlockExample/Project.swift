import ProjectDescription

/// Names the example target and its shared scheme.
private let exampleTargetName = "RorkCodeBlockExample"

/// Selects every Apple destination supported by Rork Code Block.
private let exampleDestinations: Destinations = [
  .iPhone,
  .iPad,
  .macCatalyst,
  .appleVision,
]

/// Keeps the example deployment versions aligned with the package manifest.
private let exampleDeploymentTargets = DeploymentTargets.multiplatform(
  iOS: "17.0",
  visionOS: "1.0"
)

/// Defines the generated example app and its local package dependency.
let project = Project(
  name: exampleTargetName,
  organizationName: "Rork",
  packages: [
    .package(path: "../..")
  ],
  targets: [
    .target(
      name: exampleTargetName,
      destinations: exampleDestinations,
      product: .app,
      bundleId: "ai.rork.RorkCodeBlockExample",
      deploymentTargets: exampleDeploymentTargets,
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Rork Code Block",
        "LSApplicationCategoryType": "public.app-category.developer-tools",
        "UILaunchScreen": [:],
      ]),
      sources: ["Sources/**/*.swift"],
      dependencies: [
        .package(product: "RorkCodeBlock")
      ],
      settings: .settings(
        base: [
          "CODE_SIGN_STYLE": "Automatic",
          "CURRENT_PROJECT_VERSION": "1",
          "DEVELOPMENT_TEAM": "",
          "ENABLE_PREVIEWS": "YES",
          "MARKETING_VERSION": "1.0",
          "PRODUCT_NAME": "Rork Code Block",
          "SWIFT_STRICT_CONCURRENCY": "complete",
          "SWIFT_VERSION": "6.0",
          "TARGETED_DEVICE_FAMILY": "1,2,7",
        ],
        defaultSettings: .recommended
      )
    )
  ],
  schemes: [
    .scheme(
      name: exampleTargetName,
      shared: true,
      buildAction: .buildAction(targets: [.target(exampleTargetName)]),
      runAction: .runAction(executable: .target(exampleTargetName)),
      archiveAction: .archiveAction(configuration: .release),
      profileAction: .profileAction(executable: .target(exampleTargetName)),
      analyzeAction: .analyzeAction(configuration: .debug)
    )
  ]
)
