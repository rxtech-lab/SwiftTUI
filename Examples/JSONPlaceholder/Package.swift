// swift-tools-version: 5.6

import PackageDescription

let package = Package(
  name: "JSONPlaceholder",
  platforms: [
    .macOS(.v12)
  ],
  dependencies: [
    .package(path: "../../")
  ],
  targets: [
    .executableTarget(
      name: "JSONPlaceholder",
      dependencies: ["SwiftTUI"])
  ]
)
