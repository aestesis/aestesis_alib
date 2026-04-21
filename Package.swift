// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "aestesis_alib",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "aestesis_alib",
            targets: ["aestesis_alib"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/aestesis/libtess.git", from: "1.0.5")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "aestesis_alib",
            dependencies: ["libtess", "shaders"]
        ),
        .target(
            name: "shaders",
        ),
        .testTarget(
            name: "aestesis_alibTests",
            dependencies: ["aestesis_alib"]
        ),
    ]
)
