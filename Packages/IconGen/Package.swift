// swift-tools-version: 6.0
import PackageDescription

// Dev tool, macOS only: renders the App Store icon from the game's own
// PixelKit sprites. Run via `make icon` from the repo root.
let package = Package(
    name: "IconGen",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../PixelKit"),
    ],
    targets: [
        .executableTarget(
            name: "IconGen",
            dependencies: [
                .product(name: "PixelKit", package: "PixelKit"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
