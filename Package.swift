// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Launager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BirthCore", targets: ["BirthCore"]),
        .executable(name: "Launager", targets: ["Launager"]),
    ],
    targets: [
        .target(
            name: "BirthCore"
        ),
        // The whole app lives in a library so its state/policy layer is
        // testable — SPM cannot attach tests to an executable target.
        .target(
            name: "BirthUI",
            dependencies: ["BirthCore"]
        ),
        .executableTarget(
            name: "Launager",
            dependencies: ["BirthUI"],
            path: "Sources/Birth"
        ),
        .testTarget(
            name: "BirthCoreTests",
            dependencies: ["BirthCore"]
        ),
        .testTarget(
            name: "BirthUITests",
            dependencies: ["BirthUI"]
        ),
    ]
)
