// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TycoonEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TycoonEngine", targets: ["TycoonEngine"]),
        // Iteration 12 — J4 (house field): the bots, shipped. The test
        // target measures the balance with them; the app plays the house
        // field with them.
        .library(name: "TycoonBots", targets: ["TycoonBots"]),
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
        // Iteration 12 — J4: `SimRunner`, `BotPolicy`, the pacing and
        // investor bots (moved out of the test target unchanged but for
        // `public`), and the house field's roster.
        .target(
            name: "TycoonBots",
            dependencies: [
                "TycoonEngine",
                .product(name: "TycoonContent", package: "TycoonContent"),
            ]
        ),
        .testTarget(
            name: "TycoonEngineTests",
            dependencies: [
                "TycoonEngine",
                "TycoonBots",
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
