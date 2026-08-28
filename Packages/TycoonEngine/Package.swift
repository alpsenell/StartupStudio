// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TycoonEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TycoonEngine", targets: ["TycoonEngine"])
    ],
    dependencies: [
        .package(path: "../TycoonContent")
    ],
    targets: [
        .target(
            name: "TycoonEngine",
            dependencies: [
                .product(name: "TycoonContent", package: "TycoonContent")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TycoonEngineTests",
            dependencies: [
                "TycoonEngine",
                .product(name: "TycoonContent", package: "TycoonContent"),
            ],
            // The legacy save `LegacySaveCompatibilityTests` reads: a real
            // pre-iteration-2 save file, kept as a fixture so the format
            // can never quietly break.
            resources: [.process("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
