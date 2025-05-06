// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "NetworkManager",
  platforms: [
    .iOS(.v13),
    .macOS(.v13),
    .tvOS(.v13),
    .watchOS(.v7)
  ],
  products: [
    .library(
      name: "NetworkManager",
      targets: ["NetworkManager"]
    ),
  ],
  targets: [
    .target(
      name: "NetworkManager",
      path: "Sources",
      sources: [
        "NetworkManager",
        "HeaderHandler",
        "Encoding",
        "Log",
        "Mime",
        "Error",
        "Client",
        "UploadProgress",
        "Router",
        "Data",
        "Reachability"
      ],
      swiftSettings: [
        .define("SPM_SWIFT_6"),
        .define("SWIFT_PACKAGE")
      ]
    ),
    .testTarget(
      name: "NetworkManagerTests",
      dependencies: ["NetworkManager"],
      path: "Tests/NetworkManagerTests"
    ),
  ],
  swiftLanguageModes: [.v6,.v5]
)
