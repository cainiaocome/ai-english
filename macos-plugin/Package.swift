// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacOSPlugin",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ScreenOcrPlugin",
            targets: ["ScreenOcrPlugin"]),
        .library(
            name: "TtsPlugin",
            targets: ["TtsPlugin"]),
    ],
    targets: [
        .target(
            name: "ScreenOcrPlugin",
            dependencies: []),
        .target(
            name: "TtsPlugin",
            dependencies: []),
    ]
)
