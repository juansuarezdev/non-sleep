// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vigil",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "VigilCore", path: "Sources/VigilCore"),
        .executableTarget(
            name: "Vigil",
            dependencies: ["VigilCore"],
            path: "Sources/Vigil"
        ),
        .testTarget(
            name: "VigilCoreTests",
            dependencies: ["VigilCore"],
            path: "Tests/VigilCoreTests"
        ),
    ]
)
