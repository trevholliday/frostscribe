// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Frostscribe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "frostscribe",
            targets: ["FrostscribeCLI"]
        ),
        .executable(
            name: "frostscribe-worker",
            targets: ["FrostscribeWorker"]
        ),
        .library(
            name: "FrostscribeCore",
            targets: ["FrostscribeCore"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.3.0"
        ),
    ],
    targets: [
        // Core library — shared business logic
        .target(
            name: "FrostscribeCore",
            dependencies: [],
            path: "Sources/FrostscribeCore"
        ),

        // CLI tool — interactive disc ripping
        .executableTarget(
            name: "FrostscribeCLI",
            dependencies: [
                "FrostscribeCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/FrostscribeCLI"
        ),

        // Worker daemon — launchd encode worker
        .executableTarget(
            name: "FrostscribeWorker",
            dependencies: [
                "FrostscribeCore",
            ],
            path: "Sources/FrostscribeWorker"
        ),

        // Tests
        .testTarget(
            name: "FrostscribeCoreTests",
            dependencies: ["FrostscribeCore"],
            path: "Tests/FrostscribeCoreTests"
        ),
    ]
)
