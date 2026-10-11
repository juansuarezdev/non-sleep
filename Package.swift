// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NonSleep",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NonSleepCore", path: "Sources/NonSleepCore"),
        .executableTarget(
            name: "NonSleep",
            dependencies: ["NonSleepCore"],
            path: "Sources/NonSleep"
        ),
        .testTarget(
            name: "NonSleepCoreTests",
            dependencies: ["NonSleepCore"],
            path: "Tests/NonSleepCoreTests"
        ),
    ]
)
