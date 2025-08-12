// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MPVPlayer",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MPVPlayer",
            targets: [
                "MPVPlayer"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/mpvkit/MPVKit.git", .upToNextMajor(from: "0.40.0")),
        .package(url: "https://github.com/malcommac/Repeat.git", .upToNextMajor(from: "0.6.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MPVPlayer",
            dependencies: [
                .product(name: "MPVKit", package: "MPVKit"),
                .product(name: "Repeat", package: "Repeat")
            ]
        )
    ]
)
