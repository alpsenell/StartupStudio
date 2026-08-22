// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TycoonContent",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TycoonContent", targets: ["TycoonContent"]),
    ],
    targets: [
        .target(
            name: "TycoonContent",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "TycoonContentTests",
            dependencies: ["TycoonContent"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
