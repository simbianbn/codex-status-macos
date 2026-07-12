// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexStatus",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodexStatusCore", targets: ["CodexStatusCore"]),
        .executable(name: "CodexMenuBar", targets: ["CodexMenuBar"]),
        .executable(name: "CodexStatusTests", targets: ["CodexStatusTests"])
    ],
    targets: [
        .target(name: "CodexStatusCore"),
        .executableTarget(name: "CodexMenuBar", dependencies: ["CodexStatusCore"]),
        .executableTarget(
            name: "CodexStatusTests",
            dependencies: ["CodexStatusCore"],
            path: "Tests/CodexStatusCoreTests"
        )
    ]
)
