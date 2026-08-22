// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PixelKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PixelKit", targets: ["PixelKit"]),
    ],
    targets: [
        .target(name: "PixelKit"),
        .testTarget(name: "PixelKitTests", dependencies: ["PixelKit"]),
    ],
    swiftLanguageModes: [.v6]
)
