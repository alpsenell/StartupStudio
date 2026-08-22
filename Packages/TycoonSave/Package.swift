// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TycoonSave",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TycoonSave", targets: ["TycoonSave"]),
    ],
    targets: [
        .target(name: "TycoonSave"),
        .testTarget(name: "TycoonSaveTests", dependencies: ["TycoonSave"]),
    ],
    swiftLanguageModes: [.v6]
)
