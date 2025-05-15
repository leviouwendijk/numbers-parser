// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "numbers-parser",
    dependencies: [
        // .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.29.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/leviouwendijk/plate.git", from: "1.0.2"),
        .package(url: "https://github.com/leviouwendijk/MacActor.git", from: "0.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "numbers-parser",
            dependencies: [
                // .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "plate", package: "plate"),
                .product(name: "MacActor", package: "MacActor"),
            ]
        )
    ]
)


