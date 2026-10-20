// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "CardSheetCore",
  defaultLocalization: "fr",
  platforms: [.macOS(.v26)],
  products: [
    .library(name: "Domain", targets: ["Domain"]),
    .library(name: "Rendering", targets: ["Rendering"]),
    .library(name: "Storage", targets: ["Storage"]),
    .library(name: "Printing", targets: ["Printing"]),
  ],
  targets: [
    .target(name: "Domain"),
    .target(name: "Rendering", dependencies: ["Domain"]),
    .target(name: "Storage", dependencies: ["Domain"]),
    .target(name: "Printing", dependencies: ["Domain"]),
    .testTarget(name: "DomainTests", dependencies: ["Domain"]),
    .testTarget(name: "RenderingTests", dependencies: ["Rendering"]),
    .testTarget(name: "StorageTests", dependencies: ["Storage"]),
    .testTarget(name: "PrintingTests", dependencies: ["Printing"]),
  ]
)
