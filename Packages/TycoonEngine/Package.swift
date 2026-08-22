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
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
